import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/sale.dart';
import '../../data/models/return.dart';
import '../../domain/providers/return_provider.dart';
import '../../domain/providers/sales_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/skeleton_loader.dart';

class ReturnsScreen extends ConsumerStatefulWidget {
  const ReturnsScreen({super.key});

  @override
  ConsumerState<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends ConsumerState<ReturnsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _invoiceSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _invoiceSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final returnsAsync = ref.watch(returnsListProvider);
    final returnState = ref.watch(returnFormProvider);
    final salesAsync = ref.watch(salesListProvider);
    final settingsVal = ref.watch(settingsProvider).value;
    final currency = settingsVal?.currencySymbol ?? 'Rs';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Process New Return'),
                  Tab(text: 'Returns History'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProcessReturnTab(
                  context,
                  returnState,
                  salesAsync,
                  returnsAsync,
                  currency,
                ),
                _buildReturnsHistoryTab(context, returnsAsync, currency),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessReturnTab(
    BuildContext context,
    ReturnFormState returnState,
    AsyncValue<List<Sale>> salesAsync,
    AsyncValue<List<PharmacyReturn>> returnsAsync,
    String currency,
  ) {
    return Row(
      children: [
        // Left Panel: Select Invoice
        Expanded(
          flex: 5,
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
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '1. Select Invoice to Return',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _invoiceSearchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by Invoice # or Customer name...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (val) {
                        ref.read(salesSearchQueryProvider.notifier).state = val;
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Invoice Cards Directory List
                  Expanded(
                    child: salesAsync.when(
                      data: (sales) {
                        final returnableSales = sales
                            .where(
                              (s) =>
                                  s.status == 'Completed' ||
                                  s.status == 'Partially Refunded',
                            )
                            .toList();
                        if (returnableSales.isEmpty) {
                          return const EmptyStateWidget(
                            title: 'No sales found',
                            description:
                                'No eligible sales invoices available for return processing',
                            icon: Icons.receipt_long_rounded,
                          );
                        }

                        return ListView.builder(
                          itemCount: returnableSales.length,
                          itemBuilder: (context, index) {
                            final sale = returnableSales[index];
                            final isSelected =
                                returnState.selectedSale?.id == sale.id;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryLight
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        ref
                                            .read(returnFormProvider.notifier)
                                            .setSale(sale);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        sale.invoiceNo,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                          color: isSelected
                                                              ? AppColors
                                                                    .primary
                                                              : AppColors
                                                                    .textPrimary,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              sale.status ==
                                                                  'Completed'
                                                              ? AppColors
                                                                    .successLight
                                                              : AppColors
                                                                    .warningLight,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          sale.status,
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                sale.status ==
                                                                    'Completed'
                                                                ? const Color(
                                                                    0xFF15803D,
                                                                  )
                                                                : const Color(
                                                                    0xFFB45309,
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    '${sale.customerName} • ${Formatters.date(sale.createdAt)}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              Formatters.currency(
                                                sale.totalAmount,
                                                symbol: currency,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              size: 18,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const SkeletonTableLoader(rows: 5),
                      error: (err, _) => Center(child: Text('Error: $err')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Right Panel: Return Items & Processing Form
        Expanded(
          flex: 6,
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: returnState.selectedSale == null
                  ? const EmptyStateWidget(
                      title: 'No Sale Selected',
                      description:
                          'Select an invoice from the left panel to begin return processing',
                      icon: Icons.manage_search_rounded,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selected Invoice Header Banner
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Returning Invoice #${returnState.selectedSale!.invoiceNo}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Customer: ${returnState.selectedSale!.customerName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.infoLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${returnState.selectedSale!.items.length} Purchased Items',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        const Text(
                          'Select Items to Return & Specify Reasons:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Purchased Line Items Directory
                        Builder(
                          builder: (context) {
                            final allReturnsList = returnsAsync.value ?? [];
                            final saleReturns = allReturnsList.where((r) => r.saleId == returnState.selectedSale!.id).toList();
                            Map<String, int> returnedQtyMap = {};
                            for (final rRecord in saleReturns) {
                              for (final rItem in rRecord.items) {
                                returnedQtyMap[rItem.medicineId] = (returnedQtyMap[rItem.medicineId] ?? 0) + (rItem.quantity as num).toInt();
                              }
                            }

                            return Expanded(
                              child: ListView.separated(
                                itemCount: returnState.selectedSale!.items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final saleItem =
                                      returnState.selectedSale!.items[index];
                                  final alreadyReturned = returnedQtyMap[saleItem.medicineId] ?? 0;
                                  final remainingReturnable = math.max(0, saleItem.quantity - alreadyReturned);
                                  final isFullyReturned = remainingReturnable <= 0;

                                  final existing = returnState.items.firstWhere(
                                    (i) => i.medicineId == saleItem.medicineId,
                                    orElse: () => ReturnItem(
                                      id: '',
                                      returnId: '',
                                      medicineId: saleItem.medicineId,
                                      medicineName: saleItem.medicineName,
                                      batchId: saleItem.batchId,
                                      batchNumber: saleItem.batchNumber,
                                      quantity: 0,
                                      unitPrice: saleItem.unitPrice,
                                      totalRefund: 0.0,
                                      reason: 'Customer mind change',
                                    ),
                                  );

                                  final isAdded = existing.quantity > 0;

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isFullyReturned
                                          ? const Color(0xFFF1F5F9)
                                          : (isAdded
                                              ? AppColors.primaryLight.withValues(
                                                  alpha: 0.5,
                                                )
                                              : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isFullyReturned
                                            ? AppColors.border
                                            : (isAdded
                                                ? AppColors.primary.withValues(
                                                    alpha: 0.4,
                                                  )
                                                : AppColors.border),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: isFullyReturned ? false : isAdded,
                                          activeColor: AppColors.primary,
                                          onChanged: isFullyReturned
                                              ? null
                                              : (checked) {
                                                  if (checked == true) {
                                                    ref
                                                        .read(returnFormProvider.notifier)
                                                        .addOrUpdateItem(
                                                          ReturnItem(
                                                            id: '',
                                                            returnId: '',
                                                            medicineId: saleItem.medicineId,
                                                            medicineName: saleItem.medicineName,
                                                            batchId: saleItem.batchId,
                                                            batchNumber: saleItem.batchNumber,
                                                            quantity: remainingReturnable,
                                                            unitPrice: saleItem.unitPrice,
                                                            totalRefund: remainingReturnable * saleItem.unitPrice,
                                                            reason: 'Customer mind change',
                                                          ),
                                                        );
                                                  } else {
                                                    final idx = returnState.items
                                                        .indexWhere(
                                                          (i) =>
                                                              i.medicineId ==
                                                              saleItem.medicineId,
                                                        );
                                                    if (idx >= 0) {
                                                      ref
                                                          .read(
                                                            returnFormProvider.notifier,
                                                          )
                                                          .removeItem(idx);
                                                    }
                                                  }
                                                },
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                saleItem.medicineName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: isFullyReturned ? AppColors.textSecondary : AppColors.textPrimary,
                                                  decoration: isFullyReturned ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                isFullyReturned
                                                    ? 'Purchased: ${saleItem.quantity} units (All $alreadyReturned units returned)'
                                                    : 'Purchased: ${saleItem.quantity} units • $remainingReturnable returnable • ${Formatters.currency(saleItem.unitPrice, symbol: currency)} / unit',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        if (isFullyReturned)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE2E8F0),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              '✅ Returned',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          )
                                        else if (isAdded) ...[
                                          // 1. QUANTITY STEPPER / SELECTOR
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline_rounded,
                                                    size: 16,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(
                                                    minWidth: 26,
                                                    minHeight: 26,
                                                  ),
                                                  onPressed: () {
                                                    final newQty = existing.quantity - 1;
                                                    if (newQty <= 0) {
                                                      final idx = returnState.items
                                                          .indexWhere(
                                                            (i) =>
                                                                i.medicineId ==
                                                                saleItem.medicineId,
                                                          );
                                                      if (idx >= 0) {
                                                        ref
                                                            .read(
                                                              returnFormProvider
                                                                  .notifier,
                                                            )
                                                            .removeItem(idx);
                                                      }
                                                    } else {
                                                      ref
                                                          .read(
                                                            returnFormProvider
                                                                .notifier,
                                                          )
                                                          .addOrUpdateItem(
                                                            existing.copyWith(
                                                              quantity: newQty,
                                                              totalRefund:
                                                                  newQty *
                                                                  existing.unitPrice,
                                                            ),
                                                          );
                                                    }
                                                  },
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                  ),
                                                  child: Text(
                                                    '${existing.quantity} / $remainingReturnable',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.add_circle_outline_rounded,
                                                    size: 16,
                                                    color: AppColors.primary,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(
                                                    minWidth: 26,
                                                    minHeight: 26,
                                                  ),
                                                  onPressed: existing.quantity >=
                                                          remainingReturnable
                                                      ? null
                                                      : () {
                                                          final newQty =
                                                              existing.quantity + 1;
                                                          ref
                                                              .read(
                                                                returnFormProvider
                                                                    .notifier,
                                                              )
                                                              .addOrUpdateItem(
                                                                existing.copyWith(
                                                                  quantity: newQty,
                                                                  totalRefund:
                                                                      newQty *
                                                                      existing.unitPrice,
                                                                ),
                                                              );
                                                        },
                                                ),
                                              ],
                                            ),
                                          ),
                                      const SizedBox(width: 8),

                                      // 2. REASON DROPDOWN
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: existing.reason,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'Customer mind change',
                                                child: Text('Change of mind'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Wrong Item Purchased',
                                                child: Text('Wrong Item'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Damaged / Defective',
                                                child: Text('Damaged'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'Expired',
                                                child: Text('Expired'),
                                              ),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                ref
                                                    .read(
                                                      returnFormProvider
                                                          .notifier,
                                                    )
                                                    .addOrUpdateItem(
                                                      existing.copyWith(
                                                        reason: val,
                                                      ),
                                                    );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // 3. REFUND AMOUNT BADGE
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.dangerLight,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          Formatters.currency(
                                            existing.totalRefund,
                                            symbol: currency,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // Restock Toggle Container
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Restock Returned Inventory',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: const Text(
                              'Automatically restore returned medicine quantities back to SQLite batch inventory',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            value: returnState.restockToggle,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) => ref
                                .read(returnFormProvider.notifier)
                                .toggleRestock(val),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Total Refund Summary & Confirm Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Refund Amount:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  Formatters.currency(
                                    returnState.totalRefund,
                                    symbol: currency,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: returnState.items.isEmpty
                                  ? null
                                  : () async {
                                      try {
                                        await ref
                                            .read(returnFormProvider.notifier)
                                            .submitReturn();
                                        if (context.mounted) {
                                          ToastHelper.showSuccess(
                                            context,
                                            'Return processed & refund calculated!',
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ToastHelper.showError(
                                            context,
                                            e.toString().replaceAll(
                                              'Exception: ',
                                              '',
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: const Icon(
                                Icons.assignment_return_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'CONFIRM RETURN & REFUND',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                elevation: 3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReturnsHistoryTab(
    BuildContext context,
    AsyncValue<List<PharmacyReturn>> returnsAsync,
    String currency,
  ) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Returns Ledger & History Log',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),

            Expanded(
              child: returnsAsync.when(
                data: (returns) {
                  if (returns.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No return records found',
                      description:
                          'Processed returns will appear here in the history log',
                      icon: Icons.assignment_return_rounded,
                    );
                  }

                  return ListView.builder(
                    itemCount: returns.length,
                    itemBuilder: (context, index) {
                      final ret = returns[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ExpansionTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.dangerLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.assignment_return_rounded,
                                  color: AppColors.danger,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                '${ret.returnNo} • Invoice #${ret.invoiceNo}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                'Customer: ${ret.customerName} • Date: ${Formatters.dateTime(ret.returnDate)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: Text(
                                Formatters.currency(
                                  ret.totalRefund,
                                  symbol: currency,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.danger,
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Inventory Restocked: ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            ret.restockToggle
                                                ? 'Yes (Quantities Restored)'
                                                : 'No',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Returned Line Items:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ...ret.items.map(
                                        (item) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 3,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '• ${item.medicineName} (Qty: ${item.quantity}) — Reason: ${item.reason}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                Formatters.currency(
                                                  item.totalRefund,
                                                  symbol: currency,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.danger,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
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
                  );
                },
                loading: () => const SkeletonTableLoader(rows: 5),
                error: (err, _) =>
                    Center(child: Text('Error loading returns: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
