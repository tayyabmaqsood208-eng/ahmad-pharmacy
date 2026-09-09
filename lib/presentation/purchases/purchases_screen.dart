import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../data/models/purchase.dart';
import '../../data/models/medicine.dart';
import '../../domain/providers/purchase_provider.dart';
import '../../domain/providers/medicine_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/skeleton_loader.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchasesListProvider);
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
              const Text(
                'Stock Purchases & Receiving (Vendor / Wholesaler)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showNewPurchaseDialog(context, ref),
                icon: const Icon(Icons.local_shipping_rounded, size: 16),
                label: const Text('Record New Stock Purchase'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search purchase by invoice # or vendor name...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                  ),
                  onChanged: (val) {
                    ref.read(purchaseSearchQueryProvider.notifier).state = val;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: purchasesAsync.when(
                  data: (purchases) {
                    if (purchases.isEmpty) {
                      return const EmptyStateWidget(
                        title: 'No purchase invoices recorded',
                        description:
                            'Record stock purchases from distributors/vendors to update inventory batches',
                        icon: Icons.local_shipping_rounded,
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final minTableWidth = 900.0;
                        final tableWidth = math.max(constraints.maxWidth, minTableWidth);
                        final calcSpacing = (tableWidth - 600) / 5;
                        final columnSpacing = calcSpacing > 12 ? calcSpacing : 12.0;

                        return SingleChildScrollView(
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
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF8FAFC),
                                ),
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                ),
                                columns: const [
                                    DataColumn(label: Text('Invoice #')),
                                    DataColumn(label: Text('Vendor Name')),
                                    DataColumn(label: Text('Purchase Date')),
                                    DataColumn(label: Text('Items Count')),
                                    DataColumn(label: Text('Total Amount')),
                                    DataColumn(label: Text('Status')),
                                  ],
                                  rows: purchases.map((p) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            p.invoiceNo,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(p.vendorName)),
                                        DataCell(Text(Formatters.date(p.purchaseDate))),
                                        DataCell(Text('${p.items.length} items')),
                                        DataCell(
                                          Text(
                                            Formatters.currency(
                                              p.totalAmount,
                                              symbol: currency,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.successLight,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              p.status,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF15803D),
                                              ),
                                            ),
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
                  loading: () => const SkeletonTableLoader(rows: 5),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewPurchaseDialog(BuildContext context, WidgetRef ref) {
    final vendorCtrl = TextEditingController();
    final medicinesAsync = ref.read(medicinesListProvider);

    Medicine? selectedMed;
    final batchNoCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '10');
    final buyPriceCtrl = TextEditingController();
    final sellPriceCtrl = TextEditingController();
    DateTime expiryDate = DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final formState = ref.watch(purchaseFormProvider);

          return AlertDialog(
            title: const Text(
              'Record New Stock Purchase',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 650,
              height: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: vendorCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Vendor / Distributor Name *',
                        hintText: 'e.g. Apex Pharma Wholesalers Ltd.',
                        prefixIcon: Icon(Icons.business_rounded, size: 18),
                      ),
                      onChanged: (val) => ref
                          .read(purchaseFormProvider.notifier)
                          .setVendorName(val),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Add Items to Purchase Invoice:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),

                    medicinesAsync.when(
                      data: (medicines) => DropdownButtonFormField<Medicine>(
                        decoration: const InputDecoration(
                          labelText: 'Select Medicine *',
                        ),
                        initialValue: selectedMed,
                        items: medicines
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(m.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          selectedMed = val;
                          if (val != null) {
                            buyPriceCtrl.text = '${val.defaultCostPrice}';
                            sellPriceCtrl.text = '${val.defaultPrice}';
                            batchNoCtrl.text =
                                'BAT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                          }
                        },
                      ),
                      loading: () => const SizedBox(),
                      error: (_, _) => const SizedBox(),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: batchNoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Batch # *',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity *',
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
                            controller: buyPriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Unit Cost Price *',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: sellPriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Unit Sell Price *',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ElevatedButton.icon(
                      onPressed: () {
                        if (selectedMed == null || batchNoCtrl.text.isEmpty) {
                          ToastHelper.showWarning(
                            context,
                            'Please select medicine and enter batch number',
                          );
                          return;
                        }

                        final qty = int.tryParse(qtyCtrl.text) ?? 1;
                        final buyPrice =
                            double.tryParse(buyPriceCtrl.text) ?? 0.0;
                        final sellPrice =
                            double.tryParse(sellPriceCtrl.text) ?? 0.0;

                        final item = PurchaseItem(
                          id: '',
                          purchaseId: '',
                          medicineId: selectedMed!.id,
                          medicineName: selectedMed!.name,
                          batchNumber: batchNoCtrl.text.trim(),
                          expiryDate: expiryDate,
                          quantity: qty,
                          buyPrice: buyPrice,
                          sellPrice: sellPrice,
                          subtotal: buyPrice * qty,
                        );

                        ref.read(purchaseFormProvider.notifier).addItem(item);
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Item to List'),
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    const Text(
                      'Purchase Items List:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (formState.items.isEmpty)
                      const Text(
                        'No items added yet',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      Column(
                        children: List.generate(formState.items.length, (idx) {
                          final item = formState.items[idx];
                          return ListTile(
                            dense: true,
                            title: Text(
                              '${item.medicineName} (Batch: ${item.batchNumber})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            subtitle: Text(
                              'Qty: ${item.quantity} • Cost: \$${item.buyPrice} • Subtotal: \$${item.subtotal}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: AppColors.danger,
                              ),
                              onPressed: () => ref
                                  .read(purchaseFormProvider.notifier)
                                  .removeItem(idx),
                            ),
                          );
                        }),
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
                  try {
                    await ref
                        .read(purchaseFormProvider.notifier)
                        .submitPurchase();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ToastHelper.showSuccess(
                        context,
                        'Stock purchase invoice created!',
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
                child: const Text('Submit Purchase'),
              ),
            ],
          );
        },
      ),
    );
  }
}
