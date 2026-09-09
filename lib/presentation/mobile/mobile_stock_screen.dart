import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../data/models/batch.dart';
import '../../data/models/medicine.dart';
import '../../data/models/stock_adjustment.dart';
import '../../domain/providers/inventory_provider.dart';
import '../../domain/providers/medicine_provider.dart';
import '../../domain/providers/report_provider.dart';

class MobileStockScreen extends ConsumerStatefulWidget {
  const MobileStockScreen({super.key});

  @override
  ConsumerState<MobileStockScreen> createState() => _MobileStockScreenState();
}

class _MobileStockScreenState extends ConsumerState<MobileStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _activeViewTab = 0; // 0: Products Catalog, 1: Restock History
  String _filterStatus = 'All'; // All, Low Stock, Out of Stock

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicinesListProvider);
    final adjustmentsAsync = ref.watch(stockAdjustmentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bodyDarkBg : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Title & View Tabs
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: isDark ? AppColors.cardDarkBg : Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.inventory_2_rounded, color: Color(0xFFD97706), size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Stock & Inventory',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Add or update stock directly',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showAddMedicineDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Med', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // View Toggle: Products vs Recent Restocks
                  Container(
                    height: 38,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _activeViewTab = 0),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _activeViewTab == 0
                                    ? (isDark ? AppColors.cardDarkBg : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _activeViewTab == 0
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                    : null,
                              ),
                              child: Text(
                                'Catalog Stock',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _activeViewTab == 0 ? FontWeight.bold : FontWeight.normal,
                                  color: _activeViewTab == 0 ? const Color(0xFFD97706) : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _activeViewTab = 1),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _activeViewTab == 1
                                    ? (isDark ? AppColors.cardDarkBg : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _activeViewTab == 1
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                    : null,
                              ),
                              child: Text(
                                'Recent Restocks',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _activeViewTab == 1 ? FontWeight.bold : FontWeight.normal,
                                  color: _activeViewTab == 1 ? const Color(0xFFD97706) : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab 0: Products Catalog with Search & Filter
            if (_activeViewTab == 0) ...[
              // Search & Filter Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? AppColors.cardDarkBg : Colors.white,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search medicine name, SKU, or generic...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(medicineFilterProvider.notifier).setSearchQuery('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) {
                        ref.read(medicineFilterProvider.notifier).setSearchQuery(val.trim());
                      },
                    ),
                    const SizedBox(height: 8),
                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Low Stock', 'Out of Stock'].map((status) {
                          final isSelected = _filterStatus == status;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(status, style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              onSelected: (val) {
                                setState(() => _filterStatus = status);
                              },
                              selectedColor: const Color(0xFFFEF3C7),
                              checkmarkColor: const Color(0xFFD97706),
                              labelStyle: TextStyle(
                                color: isSelected ? const Color(0xFFD97706) : AppColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Medicine Items List
              Expanded(
                child: medicinesAsync.when(
                  data: (medicines) {
                    var filtered = medicines;
                    if (_filterStatus == 'Low Stock') {
                      filtered = filtered.where((m) => m.isLowStock && !m.isOutOfStock).toList();
                    } else if (_filterStatus == 'Out of Stock') {
                      filtered = filtered.where((m) => m.isOutOfStock).toList();
                    }

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            const Text(
                              'No medicines found',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap "Add Med" to create a new product',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final med = filtered[index];
                        return _buildMedicineCard(context, med, isDark);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading inventory: $e')),
                ),
              ),
            ] else ...[
              // Tab 1: Recent Restocks Audit Log
              Expanded(
                child: adjustmentsAsync.when(
                  data: (adjustments) {
                    if (adjustments.isEmpty) {
                      return const Center(
                        child: Text(
                          'No restock adjustments recorded yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: adjustments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final adj = adjustments[index];
                        final isAdd = adj.quantityChange > 0;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDarkBg : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isAdd ? const Color(0xFFFEF3C7) : AppColors.dangerLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isAdd ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  color: isAdd ? const Color(0xFFD97706) : AppColors.danger,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      adj.medicineName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      '${adj.reason} • ${adj.createdAt.day}/${adj.createdAt.month}/${adj.createdAt.year} ${adj.createdAt.hour}:${adj.createdAt.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                    ),
                                    if (adj.notes != null && adj.notes!.isNotEmpty)
                                      Text(
                                        adj.notes!,
                                        style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isAdd ? "+" : ""}${adj.quantityChange}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isAdd ? const Color(0xFFD97706) : AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading restocks: $e')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(BuildContext context, Medicine med, bool isDark) {
    final isOut = med.isOutOfStock;
    final isLow = med.isLowStock && !isOut;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOut
              ? AppColors.danger.withValues(alpha: 0.3)
              : (isLow ? Colors.amber.withValues(alpha: 0.4) : (isDark ? AppColors.borderDark : AppColors.border)),
        ),
      ),
      child: Row(
        children: [
          // Stock badge indicator
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isOut
                  ? AppColors.dangerLight
                  : (isLow ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${med.totalStock}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isOut
                        ? AppColors.danger
                        : (isLow ? const Color(0xFFD97706) : AppColors.success),
                  ),
                ),
                Text(
                  'units',
                  style: TextStyle(
                    fontSize: 8,
                    color: isOut
                        ? AppColors.danger
                        : (isLow ? const Color(0xFFD97706) : AppColors.success),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Medicine Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${med.genericName} • ${med.category}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Rs. ${med.defaultPrice.toStringAsFixed(1)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.primary),
                    ),
                    if (med.barcode != null && med.barcode!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• ${med.barcode}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Restock Button
          ElevatedButton.icon(
            onPressed: () => _showRestockDialog(context, med),
            icon: const Icon(Icons.add_rounded, size: 14),
            label: const Text('Restock', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(60, 32),
            ),
          ),
        ],
      ),
    );
  }

  // --- RESTOCK MODAL ---
  void _showRestockDialog(BuildContext context, Medicine med) {
    int qtyToAdd = 10;
    final qtyController = TextEditingController(text: '10');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_rounded, color: Color(0xFFD97706), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Restock ${med.name}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Current Stock: ${med.totalStock} units',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text('Select or enter quantity to add:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Quick Preset Chips (+1, +5, +10, +25, +50, +100)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [1, 5, 10, 25, 50, 100].map((preset) {
                        final isSelected = qtyToAdd == preset;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('+$preset', style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            onSelected: (val) {
                              setModalState(() {
                                qtyToAdd = preset;
                                qtyController.text = preset.toString();
                              });
                            },
                            selectedColor: const Color(0xFFFEF3C7),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFFD97706) : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Numeric input & Stepper
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 28, color: Color(0xFFD97706)),
                        onPressed: () {
                          if (qtyToAdd > 1) {
                            setModalState(() {
                              qtyToAdd--;
                              qtyController.text = qtyToAdd.toString();
                            });
                          }
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            suffixText: 'units',
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val.trim());
                            if (parsed != null && parsed > 0) {
                              qtyToAdd = parsed;
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 28, color: Color(0xFFD97706)),
                        onPressed: () {
                          setModalState(() {
                            qtyToAdd++;
                            qtyController.text = qtyToAdd.toString();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Confirm Restock Action
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final qty = int.tryParse(qtyController.text.trim()) ?? qtyToAdd;
                        if (qty <= 0) return;

                        final medRepo = ref.read(medicineRepositoryProvider);
                        final invRepo = ref.read(inventoryRepositoryProvider);

                        // Ensure an active batch exists
                        final batches = await invRepo.getBatchesForMedicine(med.id);
                        Batch targetBatch;
                        if (batches.isNotEmpty) {
                          targetBatch = batches.first;
                        } else {
                          targetBatch = Batch(
                            id: const Uuid().v4(),
                            medicineId: med.id,
                            batchNumber: 'B-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                            expiryDate: DateTime.now().add(const Duration(days: 365)),
                            quantity: 0,
                            buyPrice: med.defaultCostPrice,
                            sellPrice: med.defaultPrice,
                            receivedDate: DateTime.now(),
                          );
                          await invRepo.addBatch(targetBatch);
                        }

                        // Write StockAdjustment
                        final adjustment = StockAdjustment(
                          id: const Uuid().v4(),
                          medicineId: med.id,
                          medicineName: med.name,
                          batchId: targetBatch.id,
                          batchNumber: targetBatch.batchNumber,
                          quantityChange: qty,
                          adjustmentType: 'Add',
                          reason: 'Mobile Restock',
                          createdAt: DateTime.now(),
                          notes: 'Restocked via mobile app (+$qty units)',
                        );
                        await invRepo.addStockAdjustment(adjustment, updateBatchQuantity: true);
                        await medRepo.updateMedicine(med.copyWith(totalStock: med.totalStock + qty));

                        ref.invalidate(medicinesListProvider);
                        ref.invalidate(allBatchesProvider);
                        ref.invalidate(stockAdjustmentsProvider);
                        ref.invalidate(dashboardStatsProvider);

                        HapticFeedback.mediumImpact();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ToastHelper.showSuccess(context, 'Successfully added $qty units to ${med.name}!');
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text('Confirm Restock (+$qtyToAdd Units)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
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

  // --- ADD NEW MEDICINE MODAL ---
  void _showAddMedicineDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final genericCtrl = TextEditingController();
    final barcodeCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '10');
    String selectedCategory = 'Analgesics';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_box_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Quick Add Medicine', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Medicine Name *', hintText: 'e.g. Panadol 500mg'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: genericCtrl,
                decoration: const InputDecoration(labelText: 'Generic Formula', hintText: 'e.g. Paracetamol'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: barcodeCtrl,
                decoration: const InputDecoration(labelText: 'Barcode / SKU', hintText: 'Scan or enter code'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Retail Price (PKR) *', hintText: '35'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Cost Price (PKR)', hintText: '25'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Initial Stock (Units)', hintText: '10'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final cost = double.tryParse(costCtrl.text.trim()) ?? (price * 0.8);
              final initialStock = int.tryParse(stockCtrl.text.trim()) ?? 0;
              final barcode = barcodeCtrl.text.trim();

              final newMed = Medicine(
                id: const Uuid().v4(),
                name: name,
                genericName: genericCtrl.text.trim().isNotEmpty ? genericCtrl.text.trim() : name,
                sku: 'MED-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                barcode: barcode.isNotEmpty ? barcode : null,
                category: selectedCategory,
                dosageForm: 'Tablet',
                unit: 'Box',
                packSize: 10,
                minStock: 5,
                location: 'Main Shelf',
                defaultPrice: price,
                defaultCostPrice: cost,
                totalStock: initialStock,
              );

              final medRepo = ref.read(medicineRepositoryProvider);
              final invRepo = ref.read(inventoryRepositoryProvider);

              await medRepo.addMedicine(newMed);

              if (initialStock > 0) {
                final batch = Batch(
                  id: const Uuid().v4(),
                  medicineId: newMed.id,
                  batchNumber: 'B1',
                  expiryDate: DateTime.now().add(const Duration(days: 365)),
                  quantity: initialStock,
                  buyPrice: cost,
                  sellPrice: price,
                  receivedDate: DateTime.now(),
                );
                await invRepo.addBatch(batch);

                final adjustment = StockAdjustment(
                  id: const Uuid().v4(),
                  medicineId: newMed.id,
                  medicineName: newMed.name,
                  batchId: batch.id,
                  batchNumber: batch.batchNumber,
                  quantityChange: initialStock,
                  adjustmentType: 'Add',
                  reason: 'Initial Stock (Mobile)',
                  createdAt: DateTime.now(),
                  notes: 'Created via Mobile Stock Assistant',
                );
                await invRepo.addStockAdjustment(adjustment, updateBatchQuantity: false);
              }

              ref.invalidate(medicinesListProvider);
              ref.invalidate(allBatchesProvider);
              ref.invalidate(stockAdjustmentsProvider);
              ref.invalidate(dashboardStatsProvider);

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ToastHelper.showSuccess(context, 'Medicine ${newMed.name} registered!');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            child: const Text('Save Product'),
          ),
        ],
      ),
    );
  }
}
