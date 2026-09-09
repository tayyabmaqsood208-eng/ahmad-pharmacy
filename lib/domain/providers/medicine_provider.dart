import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/medicine.dart';
import '../../data/repositories/medicine_repository.dart';

final medicineRepositoryProvider = Provider((ref) => MedicineRepository());

class MedicineFilterState {
  final String searchQuery;
  final String selectedCategory;
  final bool showLowStockOnly;

  MedicineFilterState({
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.showLowStockOnly = false,
  });

  MedicineFilterState copyWith({
    String? searchQuery,
    String? selectedCategory,
    bool? showLowStockOnly,
  }) {
    return MedicineFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      showLowStockOnly: showLowStockOnly ?? this.showLowStockOnly,
    );
  }
}

class MedicineFilterNotifier extends StateNotifier<MedicineFilterState> {
  MedicineFilterNotifier() : super(MedicineFilterState());

  void setSearchQuery(String q) => state = state.copyWith(searchQuery: q);
  void setCategory(String cat) => state = state.copyWith(selectedCategory: cat);
  void toggleLowStock(bool val) => state = state.copyWith(showLowStockOnly: val);
  void reset() => state = MedicineFilterState();
}

final medicineFilterProvider = StateNotifierProvider<MedicineFilterNotifier, MedicineFilterState>(
  (ref) => MedicineFilterNotifier(),
);

final medicinesListProvider = FutureProvider<List<Medicine>>((ref) async {
  final repo = ref.watch(medicineRepositoryProvider);
  final filter = ref.watch(medicineFilterProvider);
  return repo.getMedicines(
    query: filter.searchQuery,
    category: filter.selectedCategory,
    lowStockOnly: filter.showLowStockOnly,
  );
});

final categoriesListProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(medicineRepositoryProvider);
  return repo.getCategories();
});
