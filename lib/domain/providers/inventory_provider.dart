import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/batch.dart';
import '../../data/models/stock_adjustment.dart';
import '../../data/repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider((ref) => InventoryRepository());

final inventoryFilterStatusProvider = StateProvider<String>((ref) => 'All');
final inventorySearchQueryProvider = StateProvider<String>((ref) => '');
final inventoryTabProvider = StateProvider<String>((ref) => 'All Medicines');
final inventoryDosageFilterProvider = StateProvider<String>((ref) => 'All');

final allBatchesProvider = FutureProvider<List<Batch>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final status = ref.watch(inventoryFilterStatusProvider);
  final query = ref.watch(inventorySearchQueryProvider);
  return repo.getAllBatches(query: query, filterStatus: status);
});

final expiringBatchesProvider = FutureProvider<List<Batch>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.getExpiringBatches(withinDays: 60);
});

final stockAdjustmentsProvider = FutureProvider<List<StockAdjustment>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.getStockAdjustments();
});

