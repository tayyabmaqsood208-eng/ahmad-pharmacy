import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../../data/models/medicine.dart';
import '../../domain/providers/medicine_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/skeleton_loader.dart';

class MedicinesScreen extends ConsumerStatefulWidget {
  const MedicinesScreen({super.key});

  @override
  ConsumerState<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends ConsumerState<MedicinesScreen> {
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicinesListProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);
    final filterState = ref.watch(medicineFilterProvider);
    final settingsVal = ref.watch(settingsProvider).value;
    final currency = settingsVal?.currencySymbol ?? '\$';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Medicine Catalog Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Master drug inventory, categories, packaging units, and location racks',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditMedicineDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Add New Medicine',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search & Filters Row
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText:
                          'Search by medicine name, generic name, or SKU...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) {
                      ref
                          .read(medicineFilterProvider.notifier)
                          .setSearchQuery(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              categoriesAsync.when(
                data: (categories) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: filterState.selectedCategory,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(medicineFilterProvider.notifier)
                              .setCategory(val);
                        }
                      },
                    ),
                  ),
                ),
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text(
                  'Low Stock Only',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                selected: filterState.showLowStockOnly,
                selectedColor: AppColors.warningLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (val) {
                  ref.read(medicineFilterProvider.notifier).toggleLowStock(val);
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Medicine Catalog Table Container with Active Horizontal Slider Scrollbar
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: medicinesAsync.when(
                  data: (medicines) {
                    if (medicines.isEmpty) {
                      return const EmptyStateWidget(
                        title: 'No medicines found',
                        description:
                            'Click "Add New Medicine" to create items in your catalog',
                        icon: Icons.medication_rounded,
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final minTableWidth = 980.0;
                        final tableWidth = math.max(constraints.maxWidth, minTableWidth);
                        final calcSpacing = (tableWidth - 780) / 7;
                        final columnSpacing = calcSpacing > 12 ? calcSpacing : 12.0;

                        return SingleChildScrollView(
                          controller: _verticalScrollController,
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: tableWidth),
                              child: Theme(
                                data: Theme.of(
                                  context,
                                ).copyWith(dividerColor: const Color(0xFFF1F5F9)),
                                child: DataTable(
                                  columnSpacing: columnSpacing,
                                  horizontalMargin: 12,
                                    headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFFF8FAFC),
                                    ),
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                ),
                                dataRowMinHeight: 56,
                                dataRowMaxHeight: 64,
                                columns: const [
                                  DataColumn(label: Text('Medicine Name')),
                                  DataColumn(label: Text('Generic Name')),
                                  DataColumn(label: Text('Category')),
                                  DataColumn(label: Text('Dosage & Packaging')),
                                  DataColumn(label: Text('Rack Location')),
                                  DataColumn(label: Text('Sell Price')),
                                  DataColumn(label: Text('Stock Level')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: medicines.map((med) {
                                  final isLow = med.isLowStock;
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              med.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'SKU: ${med.sku}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          med.genericName.isNotEmpty
                                              ? med.genericName
                                              : '—',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          child: Text(
                                            med.category,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${med.dosageForm} (${med.unit})',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          med.location,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          Formatters.currency(
                                            med.defaultPrice,
                                            symbol: currency,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isLow
                                                ? AppColors.warningLight
                                                : AppColors.successLight,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '${med.totalStock} units',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isLow
                                                  ? const Color(0xFFB45309)
                                                  : const Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_rounded,
                                                size: 16,
                                                color: AppColors.info,
                                              ),
                                              tooltip: 'Edit Item',
                                              onPressed: () =>
                                                  _showAddEditMedicineDialog(
                                                    context,
                                                    ref,
                                                    existing: med,
                                                  ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 16,
                                                color: AppColors.danger,
                                              ),
                                              tooltip: 'Delete Item',
                                              onPressed: () async {
                                                final confirmed =
                                                    await ConfirmationDialog.show(
                                                      context,
                                                      title: 'Delete Medicine',
                                                      message:
                                                          'Are you sure you want to delete ${med.name}? This will remove it from the catalog.',
                                                    );
                                                if (confirmed == true) {
                                                  await ref
                                                      .read(
                                                        medicineRepositoryProvider,
                                                      )
                                                      .deleteMedicine(med.id);
                                                  ref.invalidate(
                                                    medicinesListProvider,
                                                  );
                                                  ref.invalidate(
                                                    categoriesListProvider,
                                                  );
                                                  if (context.mounted) {
                                                    ToastHelper.showSuccess(
                                                      context,
                                                      '${med.name} deleted',
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        );
                      },
                    );
                  },
                  loading: () => const SkeletonTableLoader(rows: 6),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
          ),
        ),
      ),
    ],
  ),
);
  }

  void _showAddEditMedicineDialog(
    BuildContext context,
    WidgetRef ref, {
    Medicine? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final genericCtrl = TextEditingController(
      text: existing?.genericName ?? '',
    );
    final skuCtrl = TextEditingController(text: existing?.sku ?? '');
    final categoryCtrl = TextEditingController(
      text: existing?.category ?? 'General',
    );
    final dosageCtrl = TextEditingController(
      text: existing?.dosageForm ?? 'Tablet',
    );
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'Box');
    final minStockCtrl = TextEditingController(
      text: '${existing?.minStock ?? 15}',
    );
    final locationCtrl = TextEditingController(
      text: existing?.location ?? 'Rack A-1',
    );
    final priceCtrl = TextEditingController(
      text: '${existing?.defaultPrice ?? 10.0}',
    );
    final costCtrl = TextEditingController(
      text: '${existing?.defaultCostPrice ?? 6.0}',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          existing == null ? 'Add New Medicine' : 'Edit Medicine Details',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name *',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: genericCtrl,
                  decoration: const InputDecoration(labelText: 'Generic Name'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: skuCtrl,
                        decoration: const InputDecoration(
                          labelText: 'SKU / Barcode',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: categoryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dosageCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Dosage Form (e.g. Tablet, Syrup)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Packaging Unit (e.g. Box, Strip)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Selling Price *',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cost Price *',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minStockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min Stock Threshold',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Rack Location',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                ToastHelper.showError(context, 'Medicine Name is required');
                return;
              }

              const uuid = Uuid();
              final medicine = Medicine(
                id: existing?.id ?? 'med-${uuid.v4().substring(0, 8)}',
                name: nameCtrl.text.trim(),
                genericName: genericCtrl.text.trim(),
                sku: skuCtrl.text.trim().isNotEmpty
                    ? skuCtrl.text.trim()
                    : 'SKU-${uuid.v4().substring(0, 6).toUpperCase()}',
                category: categoryCtrl.text.trim().isNotEmpty
                    ? categoryCtrl.text.trim()
                    : 'General',
                dosageForm: dosageCtrl.text.trim().isNotEmpty
                    ? dosageCtrl.text.trim()
                    : 'Tablet',
                unit: unitCtrl.text.trim().isNotEmpty
                    ? unitCtrl.text.trim()
                    : 'Box',
                minStock: int.tryParse(minStockCtrl.text) ?? 10,
                location: locationCtrl.text.trim().isNotEmpty
                    ? locationCtrl.text.trim()
                    : 'Main Rack',
                defaultPrice: double.tryParse(priceCtrl.text) ?? 0.0,
                defaultCostPrice: double.tryParse(costCtrl.text) ?? 0.0,
              );

              if (existing == null) {
                await ref
                    .read(medicineRepositoryProvider)
                    .addMedicine(medicine);
              } else {
                await ref
                    .read(medicineRepositoryProvider)
                    .updateMedicine(medicine);
              }

              ref.invalidate(medicinesListProvider);
              ref.invalidate(categoriesListProvider);

              if (context.mounted) {
                Navigator.of(context).pop();
                ToastHelper.showSuccess(context, 'Medicine saved successfully');
              }
            },
            child: const Text('Save Medicine'),
          ),
        ],
      ),
    );
  }
}
