import 'dart:io' show Platform, Directory, File, Process;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../../data/models/batch.dart';
import '../../data/models/medicine.dart';
import '../../data/models/stock_adjustment.dart';
import '../../domain/providers/inventory_provider.dart';
import '../../domain/providers/medicine_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/skeleton_loader.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicinesListProvider);
    final batchesAsync = ref.watch(allBatchesProvider);
    final selectedTab = ref.watch(inventoryTabProvider);
    final dosageFilter = ref.watch(inventoryDosageFilterProvider);
    final searchQuery = ref.watch(inventorySearchQueryProvider);
    final settingsVal = ref.watch(settingsProvider).value;
    final currency = settingsVal?.currencySymbol ?? 'PKR';

    final allMedicines = medicinesAsync.asData?.value ?? [];
    final allBatches = batchesAsync.asData?.value ?? [];

    // Map batches by medicineId
    final batchesByMed = <String, List<Batch>>{};
    for (final b in allBatches) {
      batchesByMed.putIfAbsent(b.medicineId, () => []).add(b);
    }

    // Compute Metrics for Top Stats Cards
    double totalCostValue = 0;
    double retailSalesPotential = 0;

    for (final med in allMedicines) {
      final medBatches = batchesByMed[med.id] ?? [];
      final activeBatches = medBatches.where((b) => b.quantity > 0).toList();

      if (activeBatches.isNotEmpty) {
        for (final b in activeBatches) {
          totalCostValue += (b.buyPrice * b.quantity);
          retailSalesPotential += (b.sellPrice * b.quantity);
        }
      } else {
        totalCostValue += (med.defaultCostPrice * med.totalStock);
        retailSalesPotential += (med.defaultPrice * med.totalStock);
      }
    }

    final grossProfit = retailSalesPotential - totalCostValue;
    final overallMargin = retailSalesPotential > 0
        ? (grossProfit / retailSalesPotential) * 100
        : 0.0;

    // Filter tab counts
    final lowStockCount = allMedicines.where((m) => m.isLowStock).length;
    final nearExpiryCount = allMedicines.where((m) {
      final mBatches = batchesByMed[m.id] ?? [];
      return mBatches.any((b) => b.isExpiringSoon || b.isExpired);
    }).length;

    // Build unique list of dosage forms / categories for filter chips
    final dosageOptions = <String>{'All', 'Tablet', 'Syrup', 'Injection', 'Ointment', 'Equipment'};
    for (final m in allMedicines) {
      if (m.dosageForm.isNotEmpty) dosageOptions.add(m.dosageForm);
      if (m.category.isNotEmpty) dosageOptions.add(m.category);
    }
    final sortedDosageList = dosageOptions.toList();

    // Filter medicines according to search query, selected tab, and dosage filter chip
    List<Medicine> filteredMedicines = allMedicines.where((m) {
      // 1. Search Query Filter
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final matchName = m.name.toLowerCase().contains(q);
        final matchGeneric = m.genericName.toLowerCase().contains(q);
        final matchSku = m.sku.toLowerCase().contains(q);
        if (!matchName && !matchGeneric && !matchSku) return false;
      }

      // 2. Dosage / Category Chip Filter
      if (dosageFilter != 'All') {
        final df = dosageFilter.toLowerCase();
        final mDosage = m.dosageForm.toLowerCase();
        final mCat = m.category.toLowerCase();
        if (mDosage != df && mCat != df) return false;
      }

      // 3. Tab Filter
      if (selectedTab == '💊 Medicines') {
        return !m.isGrocery;
      } else if (selectedTab == '🛒 Grocery & FMCG') {
        return m.isGrocery;
      } else if (selectedTab == 'Low Stock Alerts') {
        return m.isLowStock;
      } else if (selectedTab == 'Near-Expiry') {
        final mBatches = batchesByMed[m.id] ?? [];
        return mBatches.any((b) => b.isExpiringSoon || b.isExpired);
      }

      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP HEADER ROW (Title + Subtitle & Action Buttons)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 950;
              final headerLeft = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inventory & Product Catalog',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Master catalog for medicines, grocery & FMCG items, FEFO batch tracking & valuation.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final headerActions = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _exportInventoryToCsv(context, ref),
                      icon: const Icon(Icons.file_download_rounded, size: 16),
                      label: const Text(
                        'Export CSV',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showAuditLogModal(context, ref),
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: const Text(
                        'Stock Audit Log',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        side: const BorderSide(color: AppColors.primary, width: 1.2),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditMedicineDialog(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Add New Item',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerLeft,
                    const SizedBox(height: 12),
                    headerActions,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: headerLeft),
                  const SizedBox(width: 16),
                  headerActions,
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // 2. STATS CARDS ROW (3 summary KPI cards)
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  context,
                  title: 'Total Stock Cost Value',
                  value: '$currency ${Formatters.number(totalCostValue)}',
                  subtitle: '${allMedicines.length} Registered Products',
                  icon: Icons.savings_outlined,
                  iconBgColor: const Color(0xFFE6F5F3),
                  iconColor: const Color(0xFF0F9D8B),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  context,
                  title: 'Retail Sales Potential',
                  value: '$currency ${Formatters.number(retailSalesPotential)}',
                  subtitle: 'Expected Counter Revenue',
                  icon: Icons.trending_up_rounded,
                  iconBgColor: const Color(0xFFE0F2FE),
                  iconColor: const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKpiCard(
                  context,
                  title: 'Estimated Gross Profit',
                  value: '$currency ${Formatters.number(grossProfit)}',
                  subtitle: 'Margin: ${overallMargin.toStringAsFixed(1)}%',
                  icon: Icons.account_balance_wallet_outlined,
                  iconBgColor: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3. SUB-HEADER TAB NAVIGATION BAR
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabButton(
                    context,
                    title: 'All Products (${allMedicines.length})',
                    tabKey: 'All Products',
                    selectedTab: selectedTab,
                  ),
                  _buildTabButton(
                    context,
                    title: '💊 Medicines (${allMedicines.where((m) => !m.isGrocery).length})',
                    tabKey: '💊 Medicines',
                    selectedTab: selectedTab,
                  ),
                  _buildTabButton(
                    context,
                    title: '🛒 Grocery & FMCG (${allMedicines.where((m) => m.isGrocery).length})',
                    tabKey: '🛒 Grocery & FMCG',
                    selectedTab: selectedTab,
                  ),
                  _buildTabButton(
                    context,
                    title: 'Low Stock Alerts ($lowStockCount)',
                    tabKey: 'Low Stock Alerts',
                    selectedTab: selectedTab,
                  ),
                  _buildTabButton(
                    context,
                    title: 'Near-Expiry ($nearExpiryCount)',
                    tabKey: 'Near-Expiry',
                    selectedTab: selectedTab,
                  ),
                  _buildTabButton(
                    context,
                    title: 'Valuation Report',
                    tabKey: 'Valuation Report',
                    selectedTab: selectedTab,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. SEARCH & DOSAGE CHIPS ROW
          Row(
            children: [
              SizedBox(
                width: 360,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
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
                      hintText: 'Search by brand name, generic formula, or salt...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                    ),
                    onChanged: (val) {
                      ref.read(inventorySearchQueryProvider.notifier).state = val;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                  children: sortedDosageList.map((chipText) {
                    final isSelected = dosageFilter == chipText;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          ref.read(inventoryDosageFilterProvider.notifier).state = chipText;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE6F5F3) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                chipText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          ),
          const SizedBox(height: 16),

          // 5. MAIN MEDICINE CATALOG TABLE / CONTENT VIEW
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
                  data: (_) {
                    if (filteredMedicines.isEmpty) {
                      return EmptyStateWidget(
                        title: 'No medicines found',
                        description: selectedTab == 'Low Stock Alerts'
                            ? 'All medicines are above minimum stock levels!'
                            : (selectedTab == 'Near-Expiry'
                                ? 'No active batches are expiring in the next 60 days.'
                                : 'Try clearing filters or click "Add New Medicine"'),
                        icon: Icons.medication_rounded,
                      );
                    }

                    if (selectedTab == 'Valuation Report') {
                      return _buildValuationReportTable(
                        context,
                        filteredMedicines,
                        batchesByMed,
                        currency,
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final minTableWidth = 1020.0;
                        final tableWidth = math.max(constraints.maxWidth, minTableWidth);

                        return SingleChildScrollView(
                          controller: _verticalScrollController,
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: tableWidth),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: const Color(0xFFF1F5F9),
                                ),
                                child: DataTable(
                                  horizontalMargin: 16,
                                  columnSpacing: 20,
                                  headingRowColor: WidgetStateProperty.all(
                                    const Color(0xFFF8FAFC),
                                  ),
                                  headingTextStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                  dataRowMinHeight: 56,
                                  dataRowMaxHeight: 64,
                                  columns: const [
                                    DataColumn(label: Text('MEDICINE BRAND')),
                                    DataColumn(label: Text('GENERIC FORMULA')),
                                    DataColumn(label: Text('CATEGORY')),
                                    DataColumn(label: Text('CURRENT STOCK')),
                                    DataColumn(label: Text('COST PRICE')),
                                    DataColumn(label: Text('SALE PRICE')),
                                    DataColumn(label: Text('EARLIEST EXPIRY')),
                                    DataColumn(label: Text('ACTIONS')),
                                  ],
                                  rows: filteredMedicines.map((med) {
                                    final medBatches = batchesByMed[med.id] ?? [];
                                    final activeBatches = medBatches.where((b) => b.quantity > 0).toList();

                                    // Earliest Expiry Date calculation
                                    DateTime? earliestExpiry;
                                    if (activeBatches.isNotEmpty) {
                                      activeBatches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
                                      earliestExpiry = activeBatches.first.expiryDate;
                                    } else if (medBatches.isNotEmpty) {
                                      medBatches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
                                      earliestExpiry = medBatches.first.expiryDate;
                                    }

                                    // Pricing calculation
                                    final latestBatch = activeBatches.isNotEmpty
                                        ? (List<Batch>.from(activeBatches)..sort((a, b) => b.receivedDate.compareTo(a.receivedDate))).first
                                        : null;
                                    final costPrice = (latestBatch != null && latestBatch.buyPrice > 0)
                                        ? latestBatch.buyPrice
                                        : med.defaultCostPrice;
                                    final salePrice = (latestBatch != null && latestBatch.sellPrice > 0)
                                        ? latestBatch.sellPrice
                                        : med.defaultPrice;

                                    final isLow = med.isLowStock;
                                    final isOutOfStock = med.totalStock <= 0;

                                    return DataRow(
                                      cells: [
                                        // 1. PRODUCT BRAND & TYPE
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: med.isGrocery ? const Color(0xFFFEF3C7) : AppColors.primaryLight,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: med.isGrocery ? const Color(0xFFF59E0B) : AppColors.primary.withValues(alpha: 0.3)),
                                                ),
                                                child: Text(
                                                  med.isGrocery ? '🛒 Grocery' : '💊 Med',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: med.isGrocery ? const Color(0xFFD97706) : AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                med.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // 2. GENERIC FORMULA
                                        DataCell(
                                          Text(
                                            med.genericName.isNotEmpty ? med.genericName : '—',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),

                                        // 3. CATEGORY
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Text(
                                              med.dosageForm.isNotEmpty ? med.dosageForm : med.category,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 4. CURRENT STOCK
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isOutOfStock
                                                  ? AppColors.dangerLight
                                                  : (isLow ? AppColors.warningLight : const Color(0xFFDCFCE7)),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              '${med.totalStock} Units',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isOutOfStock
                                                    ? AppColors.danger
                                                    : (isLow ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 5. COST PRICE
                                        DataCell(
                                          Text(
                                            '$currency ${Formatters.number(costPrice)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),

                                        // 6. SALE PRICE
                                        DataCell(
                                          Text(
                                            '$currency ${Formatters.number(salePrice)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),

                                        // 7. EARLIEST EXPIRY
                                        DataCell(
                                          earliestExpiry != null
                                              ? _buildExpiryBadge(earliestExpiry)
                                              : const Text('—', style: TextStyle(color: AppColors.textLight)),
                                        ),

                                        // 8. ACTIONS
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Stock Receive / Adjust Button (Teal layers icon)
                                              InkWell(
                                                onTap: () => _showReceiveStockModal(
                                                  context,
                                                  ref,
                                                  initialMedicine: med,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE6F5F3),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.layers_outlined,
                                                    size: 16,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Edit Medicine Button (Light blue pencil icon)
                                              InkWell(
                                                onTap: () => _showAddEditMedicineDialog(
                                                  context,
                                                  ref,
                                                  existing: med,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE0F2FE),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 16,
                                                    color: Color(0xFF0284C7),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Delete Product Button (Light red trash icon)
                                              InkWell(
                                                onTap: () => _confirmDeleteMedicine(context, ref, med),
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEE2E2),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.delete_outline_rounded,
                                                    size: 16,
                                                    color: Color(0xFFDC2626),
                                                  ),
                                                ),
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
                  error: (err, _) => Center(child: Text('Error loading inventory: $err')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- KPI CARD WIDGET ---
  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SUB-HEADER TAB WIDGET ---
  Widget _buildTabButton(
    BuildContext context, {
    required String title,
    required String tabKey,
    required String selectedTab,
  }) {
    final isSelected = selectedTab == tabKey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          ref.read(inventoryTabProvider.notifier).state = tabKey;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- EXPIRY DATE BADGE WIDGET ---
  Widget _buildExpiryBadge(DateTime expiryDate) {
    final now = DateTime.now();
    final isExpired = expiryDate.isBefore(now);
    final daysLeft = expiryDate.difference(now).inDays;
    final isExpiringSoon = !isExpired && daysLeft <= 60;

    final bgColor = isExpired
        ? AppColors.dangerLight
        : (isExpiringSoon ? AppColors.warningLight : const Color(0xFFE0F2FE));
    final textColor = isExpired
        ? AppColors.danger
        : (isExpiringSoon ? const Color(0xFFB45309) : const Color(0xFF0284C7));

    final dateStr = Formatters.date(expiryDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        dateStr,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  // --- VALUATION REPORT TABLE VIEW ---
  Widget _buildValuationReportTable(
    BuildContext context,
    List<Medicine> medicines,
    Map<String, List<Batch>> batchesByMed,
    String currency,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minTableWidth = 1000.0;
        final tableWidth = math.max(constraints.maxWidth, minTableWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
                columns: const [
                  DataColumn(label: Text('MEDICINE ITEM')),
                  DataColumn(label: Text('TOTAL STOCK')),
                  DataColumn(label: Text('UNIT COST')),
                  DataColumn(label: Text('TOTAL COST VALUE')),
                  DataColumn(label: Text('UNIT RETAIL')),
                  DataColumn(label: Text('TOTAL RETAIL VALUE')),
                  DataColumn(label: Text('MARGIN %')),
                  DataColumn(label: Text('ESTIMATED PROFIT')),
                ],
                rows: medicines.map((m) {
                  final mBatches = batchesByMed[m.id] ?? [];
                  final activeBatches = mBatches.where((b) => b.quantity > 0).toList();

                  final unitCost = activeBatches.isNotEmpty ? activeBatches.first.buyPrice : m.defaultCostPrice;
                  final unitRetail = activeBatches.isNotEmpty ? activeBatches.first.sellPrice : m.defaultPrice;

                  final totalCost = unitCost * m.totalStock;
                  final totalRetail = unitRetail * m.totalStock;
                  final profit = totalRetail - totalCost;
                  final margin = totalRetail > 0 ? (profit / totalRetail) * 100 : 0.0;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          m.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      DataCell(Text('${m.totalStock} units')),
                      DataCell(Text('$currency ${Formatters.number(unitCost)}')),
                      DataCell(Text('$currency ${Formatters.number(totalCost)}')),
                      DataCell(Text('$currency ${Formatters.number(unitRetail)}')),
                      DataCell(
                        Text(
                          '$currency ${Formatters.number(totalRetail)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      DataCell(Text('${margin.toStringAsFixed(1)}%')),
                      DataCell(
                        Text(
                          '$currency ${Formatters.number(profit)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: profit >= 0 ? const Color(0xFF15803D) : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- AUDIT LOG MODAL DIALOG ---
  void _showAuditLogModal(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        final adjustmentsAsync = ref.watch(stockAdjustmentsProvider);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Stock Audit Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          content: SizedBox(
            width: 700,
            height: 450,
            child: adjustmentsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return const Center(
                    child: Text('No stock adjustment records logged yet.'),
                  );
                }
                return ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final isAdd = log.quantityChange > 0;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isAdd ? AppColors.successLight : AppColors.dangerLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAdd ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          color: isAdd ? AppColors.success : AppColors.danger,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        '${log.medicineName} (${log.adjustmentType})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Batch: ${log.batchNumber ?? '—'} • Reason: ${log.reason} • ${Formatters.dateTime(log.createdAt)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      trailing: Text(
                        '${isAdd ? '+' : ''}${log.quantityChange} units',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isAdd ? const Color(0xFF15803D) : AppColors.danger,
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const SkeletonTableLoader(rows: 5),
              error: (err, _) => Text('Error: $err'),
            ),
          ),
        );
      },
    );
  }

  // --- CONFIRM DELETE PRODUCT DIALOG ---
  void _confirmDeleteMedicine(BuildContext context, WidgetRef ref, Medicine medicine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AppColors.danger, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete ${medicine.isGrocery ? 'Grocery Item' : 'Medicine'}?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${medicine.name}"? This action cannot be undone and will remove all stock batches associated with this item.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(medicineRepositoryProvider).deleteMedicine(medicine.id);
                ref.invalidate(medicinesListProvider);
                ref.invalidate(allBatchesProvider);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ToastHelper.showSuccess(context, '${medicine.name} deleted successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ToastHelper.showError(context, 'Failed to delete product: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Product', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- EXPORT INVENTORY TO CSV ---
  Future<void> _exportInventoryToCsv(BuildContext context, WidgetRef ref) async {
    try {
      final medicines = ref.read(medicinesListProvider).value ?? [];
      final allBatches = ref.read(allBatchesProvider).value ?? [];

      final csvContent = StringBuffer();
      csvContent.writeln('AHMAD PHARMACY - INVENTORY & PRODUCT CATALOG EXPORT');
      csvContent.writeln('Export Date,${DateTime.now().toIso8601String()}');
      csvContent.writeln('');
      csvContent.writeln('Product Name,Type,Generic Formula,Category,Pack Size,Current Stock Units,Cost Price,Sale Price,Total Cost Value,Total Sale Value');

      for (final med in medicines) {
        final medBatches = allBatches.where((b) => b.medicineId == med.id && b.quantity > 0).toList();
        final latestBatch = medBatches.isNotEmpty
            ? (List<Batch>.from(medBatches)..sort((a, b) => b.receivedDate.compareTo(a.receivedDate))).first
            : null;

        final costPrice = (latestBatch != null && latestBatch.buyPrice > 0) ? latestBatch.buyPrice : med.defaultCostPrice;
        final salePrice = (latestBatch != null && latestBatch.sellPrice > 0) ? latestBatch.sellPrice : med.defaultPrice;
        final totalCostVal = med.totalStock * costPrice;
        final totalSaleVal = med.totalStock * salePrice;

        csvContent.writeln('"${med.name}",${med.productType},"${med.genericName}","${med.category}",${med.packSize},${med.totalStock},$costPrice,$salePrice,$totalCostVal,$totalSaleVal');
      }

      if (kIsWeb) {
        if (context.mounted) {
          ToastHelper.showSuccess(context, 'Inventory CSV exported successfully');
        }
        return;
      }

      Directory? targetDir;
      if (!kIsWeb && Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
        if (userProfile != null && userProfile.isNotEmpty) {
          final downloads = Directory('$userProfile\\Downloads');
          if (downloads.existsSync()) {
            targetDir = downloads;
          }
        }
      }

      targetDir ??= await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final fileName = 'Pharmacy_Inventory_Stock_$dateStr.csv';
      final filePath = '${targetDir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);

      await file.writeAsString(csvContent.toString());

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded, color: Color(0xFF15803D), size: 24),
                ),
                const SizedBox(width: 12),
                const Text('Inventory CSV Downloaded!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The product catalog CSV file has been saved directly to your system Downloads folder:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SelectableText(
                    filePath,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.all(16),
            actions: [
              if (!kIsWeb && Platform.isWindows)
                OutlinedButton.icon(
                  onPressed: () {
                    try {
                      Process.run('explorer.exe', ['/select,', filePath]);
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text('Show in Folder'),
                ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  if (!kIsWeb && Platform.isWindows) {
                    try {
                      Process.run('cmd', ['/c', 'start', '', filePath]);
                    } catch (_) {}
                  }
                },
                icon: const Icon(Icons.file_open_rounded, size: 16),
                label: const Text('Open CSV File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, 'CSV Export error: $e');
      }
    }
  }

  // --- ADD / EDIT MEDICINE DIALOG ---
  void _showAddEditMedicineDialog(
    BuildContext context,
    WidgetRef ref, {
    Medicine? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final genericCtrl = TextEditingController(text: existing?.genericName ?? '');
    final packSizeCtrl = TextEditingController(text: '${existing?.packSize ?? 10}');
    final costPriceCtrl = TextEditingController(
      text: existing != null ? '${existing.defaultCostPrice}' : '80.0',
    );
    final salePriceCtrl = TextEditingController(
      text: existing != null ? '${existing.defaultPrice}' : '120.0',
    );
    final reorderCtrl = TextEditingController(
      text: existing != null ? '${existing.minStock}' : '50',
    );
    final saltCompositionCtrl = TextEditingController(
      text: existing?.saltComposition ?? '',
    );

    String selectedProductType = existing?.productType ?? 'Medicine';

    // Categories & Form Dropdown options for Medicines & Grocery
    final medicineForms = [
      'Tablet',
      'Syrup',
      'Capsule',
      'Injection',
      'Ointment',
      'Drops',
      'Cream',
      'Equipment',
      'Antibiotics',
      'Antihistamine',
      'Antidiabetic',
      'Cardiovascular',
      'Gastrointestinal',
    ];
    final groceryForms = [
      'Beverages',
      'Snacks & Munchies',
      'Dairy & Eggs',
      'Bakery',
      'Personal Care',
      'Cosmetics',
      'Household & Cleaning',
      'Spices & Cooking',
      'Baby Care',
      'Confectionery',
      'General Grocery',
    ];

    String selectedForm = existing != null && existing.dosageForm.isNotEmpty
        ? existing.dosageForm
        : (selectedProductType == 'Grocery' ? 'Beverages' : 'Tablet');
    bool isCustomForm = false;
    final customFormCtrl = TextEditingController();

    // Primary Pack Unit options for Medicines & Grocery
    final medicineUnits = ['Strip', 'Box', 'Bottle', 'Piece', 'Pack', 'Vial', 'Tube', 'Sachet', 'Ampoule'];
    final groceryUnits = ['Piece', 'Pack', 'Kg', 'Liter', 'Gram', 'Box', 'Bottle', 'Can', 'Sachet', 'Dozen', 'Carton'];

    String selectedUnit = existing != null && existing.unit.isNotEmpty
        ? existing.unit
        : (selectedProductType == 'Grocery' ? 'Piece' : 'Strip');
    bool isCustomUnit = false;
    final customUnitCtrl = TextEditingController();

    bool requiresPrescription = existing?.requiresPrescription ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final activeForms = selectedProductType == 'Grocery' ? groceryForms : medicineForms;
          final activeUnits = selectedProductType == 'Grocery' ? groceryUnits : medicineUnits;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. DIALOG HEADER & PRODUCT TYPE SWITCHER
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              selectedProductType == 'Grocery' ? Icons.shopping_bag_rounded : Icons.medication_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            existing == null
                                ? (selectedProductType == 'Grocery' ? 'Add New Grocery Product' : 'Add New Medicine Item')
                                : 'Edit Item Details',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // PRODUCT TYPE SEGMENTED CONTROL BAR
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() {
                                  selectedProductType = 'Medicine';
                                  if (!medicineForms.contains(selectedForm)) selectedForm = 'Tablet';
                                  if (!medicineUnits.contains(selectedUnit)) selectedUnit = 'Strip';
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: selectedProductType == 'Medicine' ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.medication_rounded,
                                        size: 16,
                                        color: selectedProductType == 'Medicine' ? Colors.white : AppColors.textPrimary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '💊 Medicine (Pharmaceutical)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: selectedProductType == 'Medicine' ? Colors.white : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() {
                                  selectedProductType = 'Grocery';
                                  if (!groceryForms.contains(selectedForm)) selectedForm = 'Beverages';
                                  if (!groceryUnits.contains(selectedUnit)) selectedUnit = 'Piece';
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: selectedProductType == 'Grocery' ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.shopping_cart_rounded,
                                        size: 16,
                                        color: selectedProductType == 'Grocery' ? Colors.white : AppColors.textPrimary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '🛒 Grocery & General Item',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: selectedProductType == 'Grocery' ? Colors.white : AppColors.textPrimary,
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
                      const SizedBox(height: 20),

                      // 2. ROW 1: Product Name & Generic / Sub-category
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedProductType == 'Grocery' ? 'Brand / Product Name *' : 'Medicine Brand Name *',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: nameCtrl,
                                  decoration: InputDecoration(
                                    hintText: selectedProductType == 'Grocery' ? 'e.g. Nestle Milkpak 1L' : 'e.g. Augmentin 625mg',
                                    hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedProductType == 'Grocery' ? 'Sub-Category / Brand (Optional)' : 'Generic Formula / Name',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: genericCtrl,
                                  decoration: InputDecoration(
                                    hintText: selectedProductType == 'Grocery' ? 'e.g. Dairy / Beverages' : 'e.g. Co-Amoxiclav',
                                    hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. ROW 2: Category & Unit (with + Custom)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      selectedProductType == 'Grocery' ? 'Category / Department *' : 'Form / Category *',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          isCustomForm = !isCustomForm;
                                        });
                                      },
                                      child: Text(
                                        isCustomForm ? 'Dropdown' : '+ Custom',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (isCustomForm)
                                  TextField(
                                    controller: customFormCtrl,
                                    decoration: InputDecoration(
                                      hintText: 'Type custom category...',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                  )
                                else
                                  DropdownButtonFormField<String>(
                                    initialValue: activeForms.contains(selectedForm) ? selectedForm : activeForms.first,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                    items: activeForms
                                        .map(
                                          (f) => DropdownMenuItem(
                                            value: f,
                                            child: Text(f, style: const TextStyle(fontSize: 13)),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => selectedForm = val);
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Primary Unit *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          isCustomUnit = !isCustomUnit;
                                        });
                                      },
                                      child: Text(
                                        isCustomUnit ? 'Dropdown' : '+ Custom',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (isCustomUnit)
                                  TextField(
                                    controller: customUnitCtrl,
                                    decoration: InputDecoration(
                                      hintText: 'Type custom unit...',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                  )
                                else
                                  DropdownButtonFormField<String>(
                                    initialValue: activeUnits.contains(selectedUnit) ? selectedUnit : activeUnits.first,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                    items: activeUnits
                                        .map(
                                          (u) => DropdownMenuItem(
                                            value: u,
                                            child: Text(u, style: const TextStyle(fontSize: 13)),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => selectedUnit = val);
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 4. ROW 3: Pack Size, Purchase Cost Price, Retail Sale Price, Reorder Threshold (4 Columns)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedProductType == 'Grocery' ? 'Pack Size (Units/Carton)' : 'Pack Size (Units/Box)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: packSizeCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Purchase Cost Price',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: costPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Retail Sale Price',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: salePriceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reorder Threshold',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: reorderCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 5. ROW 4: Salt / Item Specifications (Optional)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedProductType == 'Grocery' ? 'Item Specifications / Notes (Optional)' : 'Salt Composition / Active Ingredients (Optional)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: saltCompositionCtrl,
                            decoration: InputDecoration(
                              hintText: selectedProductType == 'Grocery' ? 'e.g. 1 Liter Tetra Pack / Family Pack' : 'Amoxicillin 500mg + Clavulanic Acid 125mg',
                              hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 6. ROW 5: Prescription Required (Rx Flag) Checkbox (Only for Medicine)
                      if (selectedProductType == 'Medicine') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prescription Required (Rx Flag)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Triggers a mandatory prompt on counter billing before item can be added',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Checkbox(
                              value: requiresPrescription,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  requiresPrescription = val ?? false;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 7. FOOTER ACTION BUTTONS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  ToastHelper.showError(context, 'Product Name is required');
                                  return;
                                }

                                final finalForm = isCustomForm
                                    ? (customFormCtrl.text.trim().isNotEmpty ? customFormCtrl.text.trim() : (selectedProductType == 'Grocery' ? 'General Grocery' : 'Tablet'))
                                    : selectedForm;
                                final finalUnit = isCustomUnit
                                    ? (customUnitCtrl.text.trim().isNotEmpty ? customUnitCtrl.text.trim() : (selectedProductType == 'Grocery' ? 'Piece' : 'Strip'))
                                    : selectedUnit;

                                final parsedPackSize = int.tryParse(packSizeCtrl.text) ?? 10;
                                final finalPackSize = parsedPackSize > 0 ? parsedPackSize : 10;

                                const uuid = Uuid();
                                final medicine = Medicine(
                                  id: existing?.id ?? 'prod-${uuid.v4().substring(0, 8)}',
                                  name: name,
                                  genericName: genericCtrl.text.trim(),
                                  sku: existing?.sku ?? 'SKU-${uuid.v4().substring(0, 6).toUpperCase()}',
                                  category: finalForm,
                                  dosageForm: finalForm,
                                  unit: finalUnit,
                                  packSize: finalPackSize,
                                  minStock: int.tryParse(reorderCtrl.text) ?? 50,
                                  location: existing?.location ?? 'Main Shelf',
                                  defaultPrice: double.tryParse(salePriceCtrl.text) ?? 120.0,
                                  defaultCostPrice: double.tryParse(costPriceCtrl.text) ?? 80.0,
                                  saltComposition: saltCompositionCtrl.text.trim(),
                                  requiresPrescription: selectedProductType == 'Medicine' ? requiresPrescription : false,
                                  productType: selectedProductType,
                                );

                                if (existing == null) {
                                  await ref.read(medicineRepositoryProvider).addMedicine(medicine);

                                  // Initialize default Batch 001 with master cost & sale prices
                                  final defaultBatch = Batch(
                                    id: 'batch-${uuid.v4().substring(0, 8)}',
                                    medicineId: medicine.id,
                                    batchNumber: '001',
                                    expiryDate: DateTime.now().add(const Duration(days: 365)),
                                    quantity: 0,
                                    buyPrice: medicine.defaultCostPrice,
                                    sellPrice: medicine.defaultPrice,
                                    receivedDate: DateTime.now(),
                                  );
                                  await ref.read(inventoryRepositoryProvider).addBatch(defaultBatch);
                                } else {
                                  await ref.read(medicineRepositoryProvider).updateMedicine(medicine);
                                  // Update prices across all batches for this medicine
                                  await ref.read(inventoryRepositoryProvider).updateAllBatchPricesForMedicine(
                                    medicine.id,
                                    medicine.defaultCostPrice,
                                    medicine.defaultPrice,
                                  );
                                }

                                ref.invalidate(medicinesListProvider);
                                ref.invalidate(categoriesListProvider);
                                ref.invalidate(allBatchesProvider);

                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ToastHelper.showSuccess(context, '${selectedProductType == 'Grocery' ? 'Grocery item' : 'Medicine'} ${medicine.name} saved successfully');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ToastHelper.showError(context, 'Error saving product: $e');
                                }
                              }
                            },
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: Text(
                              selectedProductType == 'Grocery' ? 'Save Grocery Item' : 'Save Medicine',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- RECEIVE STOCK / BATCH ADJUST MODAL DIALOG ---
  void _showReceiveStockModal(
    BuildContext context,
    WidgetRef ref, {
    Batch? initialBatch,
    Medicine? initialMedicine,
  }) {
    final medicinesAsync = ref.read(medicinesListProvider);

    Medicine? selectedMed = initialMedicine;
    Batch? existingBatch = initialBatch;

    final batchNoCtrl = TextEditingController(
      text: initialBatch?.batchNumber ?? '001',
    );
    DateTime expiryDate =
        initialBatch?.expiryDate ??
        DateTime.now().add(const Duration(days: 365));
    final commercialPacksCtrl = TextEditingController(text: '0');
    final looseTabletsCtrl = TextEditingController(text: '0');

    final buyPriceCtrl = TextEditingController(
      text: initialBatch != null && initialBatch.buyPrice > 0
          ? '${initialBatch.buyPrice}'
          : (initialMedicine != null ? '${initialMedicine.defaultCostPrice}' : '80.0'),
    );
    final sellPriceCtrl = TextEditingController(
      text: initialBatch != null && initialBatch.sellPrice > 0
          ? '${initialBatch.sellPrice}'
          : (initialMedicine != null ? '${initialMedicine.defaultPrice}' : '120.0'),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final allBatches = ref.read(allBatchesProvider).asData?.value ?? [];
          final medBatches = selectedMed != null
              ? allBatches.where((b) => b.medicineId == selectedMed!.id).toList()
              : <Batch>[];

          final typedBatchNo = batchNoCtrl.text.trim();
          final matchedBatch = medBatches.firstWhere(
            (b) => b.batchNumber.toLowerCase() == typedBatchNo.toLowerCase(),
            orElse: () => existingBatch ?? (initialBatch ?? Batch(
              id: '',
              medicineId: selectedMed?.id ?? '',
              batchNumber: typedBatchNo,
              expiryDate: expiryDate,
              quantity: 0,
              buyPrice: selectedMed?.defaultCostPrice ?? 0.0,
              sellPrice: selectedMed?.defaultPrice ?? 0.0,
              receivedDate: DateTime.now(),
            )),
          );

          if (matchedBatch.id.isNotEmpty && (buyPriceCtrl.text == '100' || buyPriceCtrl.text == '80.0')) {
            if (matchedBatch.buyPrice > 0) buyPriceCtrl.text = '${matchedBatch.buyPrice}';
          }
          if (matchedBatch.id.isNotEmpty && (sellPriceCtrl.text == '200' || sellPriceCtrl.text == '120.0')) {
            if (matchedBatch.sellPrice > 0) sellPriceCtrl.text = '${matchedBatch.sellPrice}';
          }

          final currentUnits = matchedBatch.id.isNotEmpty ? matchedBatch.quantity : (existingBatch?.quantity ?? 0);
          final packSize = (selectedMed?.packSize != null && selectedMed!.packSize > 0) ? selectedMed!.packSize : 10;
          final currentPacks = currentUnits ~/ packSize;
          final currentLoose = currentUnits % packSize;

          final addedPacks = int.tryParse(commercialPacksCtrl.text) ?? 0;
          final addedLoose = int.tryParse(looseTabletsCtrl.text) ?? 0;
          final addedTotalUnits = (addedPacks * packSize) + addedLoose;

          final newTotalUnits = currentUnits + addedTotalUnits;
          final newTotalPacks = newTotalUnits ~/ packSize;
          final newTotalLoose = newTotalUnits % packSize;

          final isEditingExistingBatch = matchedBatch.id.isNotEmpty || existingBatch != null;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 18,
                        bottom: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Receive Stock / Adjust',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                selectedMed != null
                                    ? '${selectedMed!.name} (${selectedMed!.genericName})'
                                    : 'Select a medicine catalog item below',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Medicine Picker Dropdown (if not pre-selected)
                          if (selectedMed == null) ...[
                            medicinesAsync.when(
                              data: (medicines) =>
                                  DropdownButtonFormField<Medicine>(
                                    decoration: const InputDecoration(
                                      labelText: 'Select Medicine Catalog Item *',
                                      prefixIcon: Icon(
                                        Icons.medication_rounded,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                    ),
                                    initialValue: selectedMed,
                                    items: medicines
                                        .map(
                                          (m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(
                                              '${m.name} (${m.dosageForm})',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        selectedMed = val;
                                      });
                                    },
                                  ),
                              loading: () => const CircularProgressIndicator(),
                              error: (_, _) => const SizedBox(),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Existing Batches & Stock Breakdown
                          if (medBatches.isNotEmpty) ...[
                            const Text(
                              'Existing Batches & Stock Remaining',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: medBatches.map((b) {
                                  final isSelected = b.batchNumber.toLowerCase() == batchNoCtrl.text.trim().toLowerCase();
                                  final bPacks = b.quantity ~/ packSize;
                                  final bLoose = b.quantity % packSize;

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        existingBatch = b;
                                        batchNoCtrl.text = b.batchNumber;
                                        expiryDate = b.expiryDate;
                                        buyPriceCtrl.text = '${b.buyPrice}';
                                        sellPriceCtrl.text = '${b.sellPrice}';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primaryLight : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSelected ? Icons.check_circle_rounded : Icons.inventory_2_outlined,
                                            size: 14,
                                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${b.batchNumber}: ${b.quantity} units (${bPacks}P + ${bLoose}L)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Existing Batch Notice Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F5F3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF86EFAC),
                              ),
                            ),
                            child: const Text(
                              'Existing batch. This batch number is already on file. You can change expiry and prices below — saving updates the entire lot.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Batch No. Input
                          const Text(
                            'Batch no.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: batchNoCtrl,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 001 or PCM-2026B',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 14),

                          // Expiry & Commercial Packs Row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Expiry',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: expiryDate,
                                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                          lastDate: DateTime.now().add(
                                            const Duration(days: 3650),
                                          ),
                                        );
                                        if (picked != null) {
                                          setState(() => expiryDate = picked);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              Formatters.date(expiryDate),
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.calendar_month_rounded,
                                              size: 18,
                                              color: AppColors.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Quantity (commercial packs)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: commercialPacksCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Loose Tablets Input
                          const Text(
                            'Quantity (loose tablets)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: looseTabletsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 6),

                          Text(
                            'Pack size: $packSize units per pack.',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Purchase Price & Sale Price Row
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Purchase price / pack',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: buyPriceCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Sale price / pack',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: sellPriceCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Live Stock Breakdown & Preview Cards Box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Batch ${batchNoCtrl.text.trim()} Stock Summary',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isEditingExistingBatch ? AppColors.infoLight : AppColors.successLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isEditingExistingBatch ? 'Existing Lot' : 'New Lot',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isEditingExistingBatch ? AppColors.info : const Color(0xFF15803D),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Current Batch', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$currentUnits units',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            ),
                                            Text('${currentPacks}P + ${currentLoose}L', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: addedTotalUnits > 0 ? AppColors.primaryLight : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: addedTotalUnits > 0 ? AppColors.primary : AppColors.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Receiving', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                            const SizedBox(height: 2),
                                            Text(
                                              '+$addedTotalUnits units',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: addedTotalUnits > 0 ? AppColors.primary : AppColors.textPrimary),
                                            ),
                                            Text('+${addedPacks}P + ${addedLoose}L', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: addedTotalUnits > 0 ? AppColors.successLight : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: addedTotalUnits > 0 ? const Color(0xFF86EFAC) : AppColors.border),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('New Remaining', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$newTotalUnits units',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: addedTotalUnits > 0 ? const Color(0xFF15803D) : AppColors.textPrimary),
                                            ),
                                            Text('${newTotalPacks}P + ${newTotalLoose}L', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Action Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: selectedMed == null
                                      ? null
                                      : () async {
                                          try {
                                            final batchNo = batchNoCtrl.text.trim();
                                            if (batchNo.isEmpty) {
                                              ToastHelper.showError(
                                                context,
                                                'Batch number is required',
                                              );
                                              return;
                                            }

                                            final parsedBuy = double.tryParse(buyPriceCtrl.text);
                                            final buyPrice = (parsedBuy != null && parsedBuy > 0)
                                                ? parsedBuy
                                                : (matchedBatch.buyPrice > 0 ? matchedBatch.buyPrice : (selectedMed?.defaultCostPrice ?? 0.0));

                                            final parsedSell = double.tryParse(sellPriceCtrl.text);
                                            final sellPrice = (parsedSell != null && parsedSell > 0)
                                                ? parsedSell
                                                : (matchedBatch.sellPrice > 0 ? matchedBatch.sellPrice : (selectedMed?.defaultPrice ?? 0.0));
                                            final targetBatch = matchedBatch.id.isNotEmpty ? matchedBatch : existingBatch;

                                            if (targetBatch != null) {
                                              // Update existing batch
                                              final updatedBatch = targetBatch.copyWith(
                                                batchNumber: batchNo,
                                                expiryDate: expiryDate,
                                                quantity: newTotalUnits.toInt(),
                                                buyPrice: buyPrice,
                                                sellPrice: sellPrice,
                                              );
                                              await ref
                                                  .read(inventoryRepositoryProvider)
                                                  .updateBatch(updatedBatch);

                                              if (addedTotalUnits != 0) {
                                                const uuid = Uuid();
                                                final adjustment = StockAdjustment(
                                                  id: 'adj-${uuid.v4().substring(0, 8)}',
                                                  medicineId: selectedMed!.id,
                                                  medicineName: selectedMed!.name,
                                                  batchId: targetBatch.id,
                                                  batchNumber: batchNo,
                                                  quantityChange: addedTotalUnits.toInt(),
                                                  adjustmentType: addedTotalUnits > 0 ? 'Add' : 'Subtract',
                                                  reason: 'Stock Received / Adjustment',
                                                  createdAt: DateTime.now(),
                                                  notes: 'Updated expiry, pricing & quantity',
                                                );
                                                await ref
                                                    .read(inventoryRepositoryProvider)
                                                    .addStockAdjustment(adjustment, updateBatchQuantity: false);
                                              }
                                            } else {
                                              // Create new batch lot
                                              const uuid = Uuid();
                                              final batchId = 'batch-${uuid.v4().substring(0, 8)}';
                                              final newBatch = Batch(
                                                id: batchId,
                                                medicineId: selectedMed!.id,
                                                batchNumber: batchNo,
                                                expiryDate: expiryDate,
                                                quantity: newTotalUnits.toInt(),
                                                buyPrice: buyPrice,
                                                sellPrice: sellPrice,
                                                receivedDate: DateTime.now(),
                                              );
                                              await ref
                                                  .read(inventoryRepositoryProvider)
                                                  .addBatch(newBatch);

                                              if (addedTotalUnits != 0) {
                                                final adjustment = StockAdjustment(
                                                  id: 'adj-${uuid.v4().substring(0, 8)}',
                                                  medicineId: selectedMed!.id,
                                                  medicineName: selectedMed!.name,
                                                  batchId: batchId,
                                                  batchNumber: batchNo,
                                                  quantityChange: addedTotalUnits.toInt(),
                                                  adjustmentType: 'Add',
                                                  reason: 'Stock Received / New Lot',
                                                  createdAt: DateTime.now(),
                                                  notes: 'Initial lot stock addition',
                                                );
                                                await ref
                                                    .read(inventoryRepositoryProvider)
                                                    .addStockAdjustment(adjustment, updateBatchQuantity: false);
                                              }
                                            }

                                            if (selectedMed != null && (buyPrice > 0 || sellPrice > 0)) {
                                                final updatedMed = selectedMed!.copyWith(
                                                  defaultCostPrice: buyPrice > 0 ? buyPrice : selectedMed!.defaultCostPrice,
                                                  defaultPrice: sellPrice > 0 ? sellPrice : selectedMed!.defaultPrice,
                                                );
                                                await ref.read(medicineRepositoryProvider).updateMedicine(updatedMed);
                                                // Synchronize price update across all batches of this product
                                                await ref.read(inventoryRepositoryProvider).updateAllBatchPricesForMedicine(
                                                  selectedMed!.id,
                                                  updatedMed.defaultCostPrice,
                                                  updatedMed.defaultPrice,
                                                );
                                            }

                                             ref.invalidate(allBatchesProvider);
                                             ref.invalidate(medicinesListProvider);

                                            if (context.mounted) {
                                              Navigator.of(context).pop();
                                              ToastHelper.showSuccess(
                                                context,
                                                'Stock batch $batchNo saved successfully!',
                                              );
                                            }
                                          } catch (err) {
                                            if (context.mounted) {
                                              ToastHelper.showError(
                                                context,
                                                'Failed to save stock: $err',
                                              );
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    elevation: 2,
                                  ),
                                  child: const Text(
                                    'Save',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
