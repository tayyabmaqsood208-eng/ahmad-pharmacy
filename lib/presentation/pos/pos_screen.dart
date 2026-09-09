import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/medicine.dart';
import '../../data/models/batch.dart';
import '../../domain/providers/medicine_provider.dart';
import '../../domain/providers/inventory_provider.dart';
import '../../domain/providers/pos_cart_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/empty_state_widget.dart';
import 'customer_select_dialog.dart';
import 'receipt_modal.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _narrowViewTab = 0; // 0: Catalog, 1: Cart (for screens < 880px)

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicinesListProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final cartState = ref.watch(posCartProvider);
    final settingsVal = ref.watch(settingsProvider).value;
    final currency = settingsVal?.currencySymbol ?? 'Rs';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 880;

        if (isNarrow) {
          return Column(
            children: [
              // Responsive View Mode Selector Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: Theme.of(context).cardColor,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _narrowViewTab = 0),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _narrowViewTab == 0 ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _narrowViewTab == 0 ? AppColors.primary : AppColors.getBorder(context),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.medication_rounded,
                                size: 16,
                                color: _narrowViewTab == 0 ? Colors.white : AppColors.getTextSecondary(context),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Medicine Catalog',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _narrowViewTab == 0 ? Colors.white : AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _narrowViewTab = 1),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _narrowViewTab == 1 ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _narrowViewTab == 1 ? AppColors.primary : AppColors.getBorder(context),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_rounded,
                                size: 16,
                                color: _narrowViewTab == 1 ? Colors.white : AppColors.getTextSecondary(context),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Cart (${cartState.items.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _narrowViewTab == 1 ? Colors.white : AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Active View (Catalog or Cart)
              Expanded(
                child: Stack(
                  children: [
                    if (_narrowViewTab == 0) ...[
                      _buildCatalogPanel(context, ref, medicinesAsync, categoriesAsync, cartState, currency),
                      if (cartState.items.isNotEmpty)
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: InkWell(
                            onTap: () => setState(() => _narrowViewTab = 1),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${cartState.items.length} ${cartState.items.length == 1 ? 'item' : 'items'} in bill',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        Formatters.currency(cartState.grandTotal, symbol: currency),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ] else ...[
                      _buildCartPanel(context, ref, cartState, currency, isNarrow: true),
                    ],
                  ],
                ),
              ),
            ],
          );
        }

        // Wide Desktop View (Side by Side)
        final flexCatalog = constraints.maxWidth >= 1350 ? 7 : 6;
        final flexCart = constraints.maxWidth >= 1350 ? 3 : 4;

        return Row(
          children: [
            Expanded(
              flex: flexCatalog,
              child: _buildCatalogPanel(context, ref, medicinesAsync, categoriesAsync, cartState, currency),
            ),
            Expanded(
              flex: flexCart,
              child: _buildCartPanel(context, ref, cartState, currency, isNarrow: false),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCatalogPanel(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Medicine>> medicinesAsync,
    AsyncValue<List<String>> categoriesAsync,
    PosCartState cartState,
    String currency,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar & Drafts Shortcut Row
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Search medicine by name, generic name, or SKU/barcode...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(medicineFilterProvider.notifier)
                                    .setSearchQuery('');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      ref
                          .read(medicineFilterProvider.notifier)
                          .setSearchQuery(val);
                    },
                  ),
                ),
              ),
              if (cartState.parkedSales.isNotEmpty) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showParkedSalesDialog(context, ref, cartState),
                  icon: const Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                  label: Text(
                    'Drafts (${cartState.parkedSales.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.info,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    side: const BorderSide(color: AppColors.info),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Category Filter Pills
          categoriesAsync.when(
            data: (categories) {
              final filterState = ref.watch(medicineFilterProvider);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSelected =
                        filterState.selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: isSelected
                            ? AppColors.primary
                            : const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          fontSize: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: 1,
                          ),
                        ),
                        onSelected: (_) {
                          ref
                              .read(medicineFilterProvider.notifier)
                              .setCategory(cat);
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            },
            loading: () =>
                const SizedBox(height: 32, child: SkeletonLoader()),
            error: (_, _) => const SizedBox(),
          ),

          const SizedBox(height: 10),

          // Medicines Catalog Grid
          Expanded(
            child: medicinesAsync.when(
              data: (medicines) {
                if (medicines.isEmpty) {
                  return const EmptyStateWidget(
                    title: 'No medicines found',
                    description:
                        'Try adjusting your search query or category filter',
                    icon: Icons.medication_rounded,
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 4;
                    double aspectRatio = 1.6;

                    if (constraints.maxWidth < 650) {
                      crossAxisCount = 2;
                      aspectRatio = 1.45;
                    } else if (constraints.maxWidth < 1000) {
                      crossAxisCount = 3;
                      aspectRatio = 1.55;
                    } else if (constraints.maxWidth < 1400) {
                      crossAxisCount = 4;
                      aspectRatio = 1.6;
                    } else {
                      crossAxisCount = 5;
                      aspectRatio = 1.65;
                    }

                    return GridView.builder(
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: aspectRatio,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: medicines.length,
                      itemBuilder: (context, index) {
                        final medicine = medicines[index];
                        return _MedicineCardItem(
                          medicine: medicine,
                          currency: currency,
                          onLongPress: () => _showUnitSelectModal(
                            context,
                            ref,
                            medicine,
                            currency,
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const SkeletonTableLoader(rows: 4),
              error: (err, _) =>
                  Center(child: Text('Error loading catalog: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPanel(
    BuildContext context,
    WidgetRef ref,
    PosCartState cartState,
    String currency, {
    bool isNarrow = false,
  }) {
    return Container(
      margin: isNarrow ? const EdgeInsets.all(10) : const EdgeInsets.only(top: 10, right: 10, bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.getBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // If in narrow mode, show Return to Catalog Button
          if (isNarrow)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _narrowViewTab = 0),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back to Catalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Customer Header Bar & Hold Action
          _buildCustomerHeader(context, ref, cartState),

          const Divider(height: 1),

          // Cart Items List
          Expanded(
            child: cartState.items.isEmpty
                ? const EmptyStateWidget(
                    title: 'Cart is empty',
                    description:
                        'Click on medicines from the catalog to add them to the bill',
                    icon: Icons.shopping_bag_rounded,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: cartState.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 8),
                    itemBuilder: (context, index) {
                      final item = cartState.items[index];
                      return _buildCartItemTile(
                        context,
                        ref,
                        index,
                        item,
                        currency,
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // Cart Summary (Subtotal, Discount, Grand Total)
          _buildCheckoutSection(context, ref, cartState, currency),
        ],
      ),
    );
  }

  void _showUnitSelectModal(
    BuildContext context,
    WidgetRef ref,
    Medicine medicine,
    String currency,
  ) async {
    final batches = await ref
        .read(inventoryRepositoryProvider)
        .getBatchesForMedicine(medicine.id);
    Batch? selectedBatch = batches.isNotEmpty ? batches.first : null;

    final packSize = medicine.effectivePackSize;
    final boxPrice = medicine.defaultPrice;
    final tabPrice = boxPrice / packSize;
    final packs = medicine.totalStock ~/ packSize;
    final loose = medicine.totalStock % packSize;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        int selectedQty = 1;
        bool isBoxSelected = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentUnitPrice = isBoxSelected ? boxPrice : tabPrice;
            final currentTotal = currentUnitPrice * selectedQty;
            final currentUnitName = isBoxSelected
                ? (medicine.unit.isNotEmpty ? medicine.unit : 'Box')
                : (medicine.dosageForm.isNotEmpty ? medicine.dosageForm : 'Tablet');

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medicine.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (medicine.genericName.isNotEmpty)
                              Text(
                                medicine.genericName,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Stock: $packs Box, $loose Tab',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Selling Packaging Unit:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Full Box Option
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => isBoxSelected = true),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isBoxSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isBoxSelected ? AppColors.primary : AppColors.getBorder(context),
                                width: isBoxSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_rounded,
                                      size: 18,
                                      color: isBoxSelected ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Full Box (Pack)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isBoxSelected ? AppColors.primary : AppColors.getTextPrimary(context),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pack size: $packSize ${medicine.dosageForm}s',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  Formatters.currency(boxPrice, symbol: currency),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Single Tablet Option
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => isBoxSelected = false),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: !isBoxSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: !isBoxSelected ? AppColors.primary : AppColors.getBorder(context),
                                width: !isBoxSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.medication_rounded,
                                      size: 18,
                                      color: !isBoxSelected ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Single ${medicine.dosageForm} (Loose)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: !isBoxSelected ? AppColors.primary : AppColors.getTextPrimary(context),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Loose single unit',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${Formatters.currency(tabPrice, symbol: currency)} / tab',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Quantity: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: selectedQty > 1 ? () => setModalState(() => selectedQty--) : null,
                            icon: const Icon(Icons.remove_circle_outline_rounded),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$selectedQty',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setModalState(() => selectedQty++),
                            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                          ),
                        ],
                      ),
                      Text(
                        'Total: ${Formatters.currency(currentTotal, symbol: currency)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.read(posCartProvider.notifier).addItem(
                          medicine,
                          selectedBatch: selectedBatch,
                          isFullBox: isBoxSelected,
                          quantity: selectedQty,
                        );
                        Navigator.of(ctx).pop();
                        ToastHelper.showSuccess(ctx, 'Added $selectedQty $currentUnitName of ${medicine.name}');
                      },
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: Text('Add to Bill ($selectedQty $currentUnitName)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerHeader(
    BuildContext context,
    WidgetRef ref,
    PosCartState cartState,
  ) {
    final customer = cartState.selectedCustomer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer?.name ?? 'Walk-in Customer',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  customer != null
                      ? (customer.phone.isNotEmpty
                            ? customer.phone
                            : 'Registered')
                      : 'Default walk-in sale',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (cartState.items.isNotEmpty) ...[
            IconButton(
              icon: const Icon(
                Icons.pause_circle_outline_rounded,
                size: 20,
                color: AppColors.info,
              ),
              tooltip: 'Hold / Park Current Sale Draft',
              onPressed: () {
                final noteCtrl = TextEditingController();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Hold / Park Sale Draft'),
                    content: TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Customer note or description (optional)',
                      ),
                    ),
                    actions: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ref
                              .read(posCartProvider.notifier)
                              .parkCurrentSale(noteCtrl.text.trim());
                          Navigator.of(context).pop();
                          ToastHelper.showInfo(
                            context,
                            'Current sale saved to drafts!',
                          );
                        },
                        child: const Text('Park Sale'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
          ],
          OutlinedButton.icon(
            onPressed: () => CustomerSelectDialog.show(context),
            icon: const Icon(Icons.person_add_rounded, size: 13),
            label: Text(
              customer != null ? 'Change' : 'Select',
              style: const TextStyle(fontSize: 11),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(
    BuildContext context,
    WidgetRef ref,
    int index,
    dynamic item,
    String currency,
  ) {
    final packSize = (item.medicine.packSize > 0) ? item.medicine.packSize : 1;
    final isMultiPack = packSize > 1;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      item.medicine.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMultiPack) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Click to switch between Box and Tablet',
                      child: InkWell(
                        onTap: () => ref.read(posCartProvider.notifier).toggleItemUnit(index),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: item.isFullBox
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: item.isFullBox
                                  ? AppColors.primary
                                  : Colors.amber.shade700,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.unitLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: item.isFullBox
                                      ? AppColors.primary
                                      : Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.sync_rounded,
                                size: 9,
                                color: item.isFullBox
                                    ? AppColors.primary
                                    : Colors.amber.shade900,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (item.selectedBatch != null)
                Text(
                  'Batch: ${item.selectedBatch!.batchNumber}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              Text(
                '${Formatters.currency(item.unitPrice, symbol: currency)} / ${item.unitLabel}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => ref
                  .read(posCartProvider.notifier)
                  .updateQuantity(index, item.quantity - 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => ref
                  .read(posCartProvider.notifier)
                  .updateQuantity(index, item.quantity + 1),
            ),
          ],
        ),

        const SizedBox(width: 10),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Formatters.currency(item.total, symbol: currency),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
            InkWell(
              onTap: () => ref.read(posCartProvider.notifier).removeItem(index),
              child: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckoutSection(
    BuildContext context,
    WidgetRef ref,
    PosCartState cartState,
    String currency,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subtotal Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Subtotal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formatters.currency(cartState.subtotal, symbol: currency),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Discount Row with Edit Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: InkWell(
                    onTap: () =>
                        _showDiscountDialog(context, ref, cartState, currency),
                    borderRadius: BorderRadius.circular(6),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text(
                            'Discount ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.infoLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  cartState.discountAmount > 0
                      ? '- ${Formatters.currency(cartState.discountAmount, symbol: currency)}'
                      : Formatters.currency(0, symbol: currency),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: cartState.discountAmount > 0
                        ? AppColors.danger
                        : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Grand Total Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Grand Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formatters.currency(cartState.grandTotal, symbol: currency),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Payment Methods Choice Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Cash', 'Card', 'Mobile', 'Credit'].map((method) {
                  final isSel = cartState.paymentMethod == method;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(method),
                      selected: isSel,
                      selectedColor: AppColors.primary,
                      backgroundColor: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSel ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      ),
                      onSelected: (_) {
                        ref
                            .read(posCartProvider.notifier)
                            .setPaymentMethod(method);
                        if (method == 'Credit' && cartState.selectedCustomer == null) {
                          ToastHelper.showWarning(
                            context,
                            'Customer selection is compulsory for Credit billing!',
                          );
                          CustomerSelectDialog.show(context);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            if (cartState.paymentMethod == 'Credit' && cartState.selectedCustomer == null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.danger),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Customer selection is COMPULSORY for Credit billing!',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => CustomerSelectDialog.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '+ Select',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: cartState.items.isEmpty
                    ? null
                    : () async {
                        if (cartState.paymentMethod == 'Credit' && cartState.selectedCustomer == null) {
                          ToastHelper.showError(
                            context,
                            'Customer selection is compulsory for Credit billing! Please select or add customer details.',
                          );
                          CustomerSelectDialog.show(context);
                          return;
                        }
                        try {
                          final sale = await ref
                              .read(posCartProvider.notifier)
                              .processCheckout();
                          if (context.mounted) {
                            ToastHelper.showSuccess(
                              context,
                              'Invoice #${sale.invoiceNo} completed!',
                            );
                            ReceiptModal.show(
                              context,
                              sale,
                              currencySymbol: currency,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ToastHelper.showError(
                              context,
                              e.toString().replaceAll('Exception: ', ''),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text(
                  'COMPLETE SALE (CHECKOUT)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: cartState.items.isEmpty ? 0 : 3,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscountDialog(
    BuildContext context,
    WidgetRef ref,
    PosCartState cartState,
    String currency,
  ) {
    final discountCtrl = TextEditingController(
      text: cartState.discountAmount > 0 ? '${cartState.discountAmount}' : '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Apply Cart Discount',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: discountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Discount Amount ($currency)',
                  hintText: 'Enter discount amount',
                  prefixIcon: const Icon(Icons.discount_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [5, 10, 15, 20].map((pct) {
                  return OutlinedButton(
                    onPressed: () {
                      final calculated = (cartState.subtotal * pct) / 100;
                      discountCtrl.text = calculated.toStringAsFixed(2);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    child: Text('$pct%'),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              ref.read(posCartProvider.notifier).setDiscount(0.0);
              Navigator.of(context).pop();
              ToastHelper.showInfo(context, 'Discount cleared');
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(discountCtrl.text) ?? 0.0;
              ref.read(posCartProvider.notifier).setDiscount(amt);
              Navigator.of(context).pop();
              ToastHelper.showSuccess(context, 'Discount applied');
            },
            child: const Text('Apply Discount'),
          ),
        ],
      ),
    );
  }

  void _showParkedSalesDialog(
    BuildContext context,
    WidgetRef ref,
    PosCartState cartState,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Parked / Held Draft Sales',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 450,
          height: 350,
          child: cartState.parkedSales.isEmpty
              ? const Center(child: Text('No held sales available'))
              : ListView.separated(
                  itemCount: cartState.parkedSales.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final parked = cartState.parkedSales[index];
                    return ListTile(
                      title: Text(
                        parked.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${parked.items.length} items • ${Formatters.dateTime(parked.createdAt)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            onPressed: () {
                              ref
                                  .read(posCartProvider.notifier)
                                  .resumeParkedSale(parked);
                              Navigator.of(context).pop();
                              ToastHelper.showSuccess(
                                context,
                                'Draft sale resumed',
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.danger,
                              size: 18,
                            ),
                            onPressed: () {
                              ref
                                  .read(posCartProvider.notifier)
                                  .discardParkedSale(parked.id);
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _MedicineCardItem extends ConsumerStatefulWidget {
  final Medicine medicine;
  final String currency;
  final VoidCallback? onLongPress;

  const _MedicineCardItem({
    required this.medicine,
    required this.currency,
    this.onLongPress,
  });

  @override
  ConsumerState<_MedicineCardItem> createState() => _MedicineCardItemState();
}

class _MedicineCardItemState extends ConsumerState<_MedicineCardItem> {
  // By default, select Single Tablet!
  bool _isBox = false;

  void _addToCart(bool isFullBox) async {
    final batches = await ref
        .read(inventoryRepositoryProvider)
        .getBatchesForMedicine(widget.medicine.id);
    Batch? selectedBatch;
    if (batches.isNotEmpty) {
      selectedBatch = batches.first;
    }
    ref.read(posCartProvider.notifier).addItem(
      widget.medicine,
      selectedBatch: selectedBatch,
      isFullBox: isFullBox,
    );
    final unit = isFullBox
        ? (widget.medicine.unit.isNotEmpty ? widget.medicine.unit : 'Box')
        : (widget.medicine.dosageForm.isNotEmpty ? widget.medicine.dosageForm : 'Tablet');
    if (mounted) {
      ToastHelper.showSuccess(context, 'Added 1 $unit of ${widget.medicine.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicine = widget.medicine;
    final isOut = medicine.isOutOfStock;
    final isLow = medicine.isLowStock;
    final isMultiPack = medicine.isTabletOrPack;
    final packSize = medicine.effectivePackSize;
    final packs = medicine.totalStock ~/ packSize;
    final loose = medicine.totalStock % packSize;

    final boxPrice = medicine.defaultPrice;
    final tabPrice = boxPrice / packSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String stockText;
    if (isOut) {
      stockText = 'Out';
    } else if (isMultiPack) {
      if (packs > 0 && loose > 0) {
        stockText = '$packs Box, $loose Tab';
      } else if (packs > 0) {
        stockText = '$packs ${medicine.unit}${packs == 1 ? '' : 's'}';
      } else {
        stockText = '$loose ${medicine.dosageForm}${loose == 1 ? '' : 's'}';
      }
    } else {
      stockText = '${medicine.totalStock} in stock';
    }

    final String subtitleText = medicine.genericName.isNotEmpty
        ? (isMultiPack
            ? '${medicine.genericName} • 1x$packSize'
            : medicine.genericName)
        : (isMultiPack
            ? '${medicine.dosageForm} • 1x$packSize'
            : '${medicine.dosageForm} • ${medicine.unit}');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLow
              ? AppColors.danger.withValues(alpha: 0.35)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isLow ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isOut
                ? () => ToastHelper.showWarning(
                    context,
                    '${medicine.name} is Out of Stock!',
                  )
                : () => _addToCart(isMultiPack ? _isBox : true),
            onLongPress: widget.onLongPress,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Icon, Name, Subtitle, and Stock Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: medicine.isGrocery
                              ? const Color(0xFFFEF3C7)
                              : (isDark
                                  ? AppColors.primary.withValues(alpha: 0.18)
                                  : AppColors.primaryLight),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          medicine.isGrocery
                              ? Icons.shopping_cart_rounded
                              : Icons.medication_rounded,
                          color: medicine.isGrocery
                              ? const Color(0xFFD97706)
                              : AppColors.primary,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medicine.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              subtitleText,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppColors.getTextSecondary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isOut
                              ? AppColors.dangerLight
                              : (isLow
                                    ? AppColors.warningLight
                                    : AppColors.successLight),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isOut
                                    ? AppColors.danger
                                    : (isLow
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF15803D)),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              stockText,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: isOut
                                    ? AppColors.danger
                                    : (isLow
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF15803D)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  // Row 2: Segmented Unit Toggle (Only for multi-pack items)
                  if (isMultiPack) ...[
                    Container(
                      height: 22,
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Tablet Tab (Default!)
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (_isBox) setState(() => _isBox = false);
                              },
                              borderRadius: BorderRadius.circular(4.5),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !_isBox
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4.5),
                                ),
                                child: Text(
                                  'Tablet',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: !_isBox
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: !_isBox
                                        ? Colors.white
                                        : AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Box Tab
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (!_isBox) setState(() => _isBox = true);
                              },
                              borderRadius: BorderRadius.circular(4.5),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _isBox
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4.5),
                                ),
                                child: Text(
                                  'Box ($packSize)',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: _isBox
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: _isBox
                                        ? Colors.white
                                        : AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Row 3: Dynamic Price & Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Dynamic Price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  Formatters.currency(
                                    isMultiPack
                                        ? (_isBox ? boxPrice : tabPrice)
                                        : medicine.defaultPrice,
                                    symbol: widget.currency,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (isMultiPack) ...[
                                  const SizedBox(width: 2),
                                  Text(
                                    _isBox ? '/box' : '/tab',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          AppColors.getTextSecondary(context),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (isMultiPack)
                              Text(
                                _isBox
                                    ? 'Tab: ${Formatters.currency(tabPrice, symbol: widget.currency)}'
                                    : 'Box: ${Formatters.currency(boxPrice, symbol: widget.currency)}',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppColors.getTextSecondary(context)
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Compact Button on the medicine
                      Material(
                        color: isOut
                            ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300)
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          onTap: isOut
                              ? null
                              : () => _addToCart(isMultiPack ? _isBox : true),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_shopping_cart_rounded,
                                  size: 12,
                                  color: isOut
                                      ? Colors.grey.shade500
                                      : Colors.white,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isMultiPack
                                      ? (_isBox ? '+ Box' : '+ Tab')
                                      : '+ Add',
                                  style: TextStyle(
                                    color: isOut
                                        ? Colors.grey.shade500
                                        : Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

