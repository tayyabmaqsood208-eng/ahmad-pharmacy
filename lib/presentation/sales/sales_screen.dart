import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../domain/providers/sales_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../pos/receipt_modal.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesListProvider);
    final statusFilter = ref.watch(salesStatusFilterProvider);
    final paymentFilter = ref.watch(salesPaymentMethodFilterProvider);
    final settingsVal = ref.watch(settingsProvider).value;
    final currency = settingsVal?.currencySymbol ?? 'Rs';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sales History & Transactions Ledger', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text('Audit log of all completed, refunded, and voided point-of-sale invoices', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),

          // Search & Filter Dropdowns Row
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
                      hintText: 'Search by invoice # or customer name...',
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) {
                      ref.read(salesSearchQueryProvider.notifier).state = val;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: statusFilter,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 18),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Statuses', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'Completed', child: Text('Completed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'Refunded', child: Text('Refunded', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'Voided', child: Text('Voided', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    ],
                    onChanged: (val) {
                      if (val != null) ref.read(salesStatusFilterProvider.notifier).state = val;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: paymentFilter,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 18),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Payment Methods', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'Card', child: Text('Card', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'Mobile', child: Text('Mobile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      DropdownMenuItem(value: 'Credit', child: Text('Store Credit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    ],
                    onChanged: (val) {
                      if (val != null) ref.read(salesPaymentMethodFilterProvider.notifier).state = val;
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Sales History Data Table Container with Horizontal Scrollbar Slider
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
                child: salesAsync.when(
                  data: (sales) {
                    if (sales.isEmpty) {
                      return const EmptyStateWidget(
                        title: 'No sales transactions found',
                        description: 'Completed transactions from POS will be recorded here',
                        icon: Icons.receipt_long_rounded,
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final minTableWidth = 960.0;
                        final tableWidth = math.max(constraints.maxWidth, minTableWidth);
                        final calcSpacing = (tableWidth - 700) / 6;
                        final columnSpacing = calcSpacing > 12 ? calcSpacing : 12.0;

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
                                  columnSpacing: columnSpacing,
                                  horizontalMargin: 12,
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)),
                                dataRowMinHeight: 52,
                                dataRowMaxHeight: 56,
                                columns: const [
                                  DataColumn(label: Text('Invoice #')),
                                  DataColumn(label: Text('Customer Name')),
                                  DataColumn(label: Text('Date & Time')),
                                  DataColumn(label: Text('Payment Method')),
                                  DataColumn(label: Text('Total Amount')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: sales.map((sale) {
                                  final isVoided = sale.status == 'Voided';
                                  final isRefunded = sale.status == 'Refunded';

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          sale.invoiceNo,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          sale.customerName,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          Formatters.dateTime(sale.createdAt),
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: Text(
                                            sale.paymentMethod,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          Formatters.currency(sale.totalAmount, symbol: currency),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isVoided
                                                ? AppColors.dangerLight
                                                : (isRefunded ? AppColors.warningLight : AppColors.successLight),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            sale.status,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isVoided
                                                  ? AppColors.danger
                                                  : (isRefunded ? const Color(0xFFB45309) : const Color(0xFF15803D)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.visibility_rounded, size: 16, color: AppColors.info),
                                              tooltip: 'View / Print Invoice Receipt',
                                              onPressed: () => ReceiptModal.show(context, sale, currencySymbol: currency),
                                            ),
                                            if (!isVoided)
                                              IconButton(
                                                icon: const Icon(Icons.block_rounded, size: 16, color: AppColors.danger),
                                                tooltip: 'Void Invoice Sale',
                                                onPressed: () async {
                                                  final confirmed = await ConfirmationDialog.show(
                                                    context,
                                                    title: 'Void Sale Invoice #${sale.invoiceNo}',
                                                    message: 'Voiding this sale will return items to batch inventory and cancel payment. Proceed?',
                                                    confirmLabel: 'Void Sale',
                                                  );
                                                  if (confirmed == true) {
                                                    await ref.read(voidSaleProvider.notifier).voidSale(sale.id, 'Manager void');
                                                    if (context.mounted) {
                                                      ToastHelper.showSuccess(context, 'Sale #${sale.invoiceNo} voided');
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
}
