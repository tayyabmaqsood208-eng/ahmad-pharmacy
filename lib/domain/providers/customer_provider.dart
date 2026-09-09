import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';

final customerRepositoryProvider = Provider((ref) => CustomerRepository());

final customerSearchQueryProvider = StateProvider<String>((ref) => '');
final customerCreditFilterProvider = StateProvider<bool>((ref) => false);

final customersListProvider = FutureProvider<List<Customer>>((ref) async {
  final repo = ref.watch(customerRepositoryProvider);
  final query = ref.watch(customerSearchQueryProvider);
  final creditOnly = ref.watch(customerCreditFilterProvider);

  return repo.getCustomers(query: query, hasCreditOnly: creditOnly);
});

class CustomerActionNotifier extends StateNotifier<AsyncValue<void>> {
  final CustomerRepository _repo;
  final Ref _ref;

  CustomerActionNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> addCustomer(Customer customer) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addCustomer(customer);
      _ref.invalidate(customersListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateCustomer(customer);
      _ref.invalidate(customersListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> payCredit(String customerId, double amount) async {
    state = const AsyncValue.loading();
    try {
      await _repo.payCustomerCredit(customerId, amount);
      _ref.invalidate(customersListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteCustomer(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteCustomer(id);
      _ref.invalidate(customersListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final customerActionProvider = StateNotifierProvider<CustomerActionNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return CustomerActionNotifier(repo, ref);
});
