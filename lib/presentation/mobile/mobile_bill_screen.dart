import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_helper.dart';
import '../../data/models/medicine.dart';
import '../../domain/providers/customer_provider.dart';
import '../../domain/providers/inventory_provider.dart';
import '../../domain/providers/medicine_provider.dart';
import '../../domain/providers/pos_cart_provider.dart';
import '../../domain/providers/report_provider.dart';
import '../../domain/providers/scanner_provider.dart';
import '../pos/receipt_modal.dart';

class MobileBillScreen extends ConsumerStatefulWidget {
  const MobileBillScreen({super.key});

  @override
  ConsumerState<MobileBillScreen> createState() => _MobileBillScreenState();
}

class _MobileBillScreenState extends ConsumerState<MobileBillScreen> {
  final TextEditingController _quickSearchController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _quickSearchController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(posCartProvider);
    final clientState = ref.watch(scannerClientProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bodyDarkBg : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Customer & Clear Action
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Active Sale Bill',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${cartState.totalItemCount} items in bill',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (cartState.items.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            ref.read(posCartProvider.notifier).clearCart();
                            HapticFeedback.selectionClick();
                          },
                          icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.danger),
                          label: const Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Customer Selector Chip Bar
                  InkWell(
                    onTap: () => _showCustomerSelectDialog(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cartState.selectedCustomer != null
                                  ? '${cartState.selectedCustomer!.name} (${cartState.selectedCustomer!.phone})'
                                  : 'Walk-in Customer (Tap to change)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Quick Add Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? AppColors.cardDarkBg : Colors.white,
              child: Autocomplete<Medicine>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.trim().isEmpty) return const Iterable<Medicine>.empty();
                  final medicines = await ref.read(medicinesListProvider.future);
                  final query = textEditingValue.text.toLowerCase();
                  return medicines.where(
                    (m) =>
                        m.name.toLowerCase().contains(query) ||
                        m.genericName.toLowerCase().contains(query) ||
                        m.sku.toLowerCase().contains(query) ||
                        (m.barcode != null && m.barcode!.toLowerCase().contains(query)),
                  );
                },
                displayStringForOption: (Medicine m) => '${m.name} (Rs. ${m.defaultPrice.toStringAsFixed(0)})',
                onSelected: (Medicine selection) {
                  ref.read(posCartProvider.notifier).addItem(
                        selection,
                        isFullBox: !selection.isTabletOrPack,
                        quantity: 1,
                      );
                  HapticFeedback.lightImpact();
                  ToastHelper.showSuccess(context, 'Added ${selection.name} to bill');
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Quick search medicine to add to bill...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                  );
                },
              ),
            ),

            // Cart Items List
            Expanded(
              child: cartState.items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 54, color: Colors.grey.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          const Text(
                            'Bill is currently empty',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Scan medicine barcodes or search above to add items',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: cartState.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = cartState.items[index];
                        return _buildCartItemCard(context, item, index, isDark);
                      },
                    ),
            ),

            // Bottom Summary & Checkout Bar
            if (cartState.items.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkBg : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Subtotal and Total Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Subtotal:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text(
                              'Rs. ${cartState.subtotal.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Grand Total:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text(
                              'Rs. ${cartState.grandTotal.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Payment Method & Discount Row
                    Row(
                      children: [
                        // Payment Method Chips (Cash, Card, Credit)
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ['Cash', 'Card', 'Credit'].map((method) {
                                final isSelected = cartState.paymentMethod == method;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(method, style: const TextStyle(fontSize: 11)),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      ref.read(posCartProvider.notifier).setPaymentMethod(method);
                                    },
                                    selectedColor: AppColors.primaryLight,
                                    labelStyle: TextStyle(
                                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        // Discount Input Button
                        TextButton.icon(
                          onPressed: () => _showDiscountDialog(context, cartState.discountAmount),
                          icon: const Icon(Icons.discount_outlined, size: 14),
                          label: Text(
                            cartState.discountAmount > 0
                                ? 'Disc: -${cartState.discountAmount.toStringAsFixed(0)}'
                                : 'Add Discount',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Primary Checkout Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _handleCheckout(context),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 20),
                        label: Text(
                          _isProcessing ? 'Processing Bill...' : 'Complete & Print Bill (Rs. ${cartState.grandTotal.toStringAsFixed(0)})',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    // Secondary Push to POS Terminal (if paired)
                    if (clientState.isConnected) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Connected to POS Terminal (${clientState.serverName.isNotEmpty ? clientState.serverName : "Counter PC"})',
                        style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, dynamic item, int index, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.medicine.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '${item.medicine.genericName} • ${item.unitLabel}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    if (item.selectedBatch != null)
                      Text(
                        'Batch: ${item.selectedBatch.batchNumber}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${item.total.toStringAsFixed(1)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                  ),
                  Text(
                    '@ Rs. ${item.unitPrice.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Unit toggle (Box vs Unit) if supported
              if (item.medicine.isTabletOrPack)
                InkWell(
                  onTap: () {
                    ref.read(posCartProvider.notifier).toggleItemUnit(index);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.isFullBox ? 'Box Mode' : 'Loose Unit',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),

              // Quantity Stepper
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 22, color: AppColors.textSecondary),
                    onPressed: () {
                      ref.read(posCartProvider.notifier).updateQuantity(index, item.quantity - 1);
                      HapticFeedback.selectionClick();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: AppColors.primary),
                    onPressed: () {
                      ref.read(posCartProvider.notifier).updateQuantity(index, item.quantity + 1);
                      HapticFeedback.selectionClick();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 14),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                    onPressed: () {
                      ref.read(posCartProvider.notifier).removeItem(index);
                      HapticFeedback.selectionClick();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckout(BuildContext context) async {
    setState(() => _isProcessing = true);
    try {
      final sale = await ref.read(posCartProvider.notifier).processCheckout();

      ref.invalidate(medicinesListProvider);
      ref.invalidate(allBatchesProvider);
      ref.invalidate(dashboardStatsProvider);

      HapticFeedback.mediumImpact();
      if (context.mounted) {
        ReceiptModal.show(context, sale);
        ToastHelper.showSuccess(context, 'Sale recorded! Invoice: ${sale.invoiceNo}');
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showDiscountDialog(BuildContext context, double currentDiscount) {
    _discountController.text = currentDiscount > 0 ? currentDiscount.toStringAsFixed(0) : '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Discount (PKR)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _discountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Discount amount...',
            suffixText: 'Rs.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(posCartProvider.notifier).setDiscount(0.0);
              Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(_discountController.text.trim()) ?? 0.0;
              ref.read(posCartProvider.notifier).setDiscount(val);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showCustomerSelectDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final customersAsync = ref.watch(customersListProvider);
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Customer for Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                    title: const Text('Walk-in Customer'),
                    subtitle: const Text('Standard generic receipt'),
                    onTap: () {
                      ref.read(posCartProvider.notifier).setCustomer(null);
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: customersAsync.when(
                      data: (customers) {
                        return ListView.builder(
                          itemCount: customers.length,
                          itemBuilder: (context, idx) {
                            final c = customers[idx];
                            return ListTile(
                              leading: const Icon(Icons.account_circle_rounded),
                              title: Text(c.name),
                              subtitle: Text(c.phone),
                              onTap: () {
                                ref.read(posCartProvider.notifier).setCustomer(c);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
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
}
