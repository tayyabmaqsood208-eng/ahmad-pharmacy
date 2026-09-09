import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../../data/models/customer.dart';
import '../../domain/providers/customer_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../core/widgets/skeleton_loader.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);
    final creditOnly = ref.watch(customerCreditFilterProvider);
    final settingsVal = ref.watch(settingsProvider).value;
    final currency = settingsVal?.currencySymbol ?? 'Rs';

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
                  const Text('Customer Directory & Credit Ledger', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Customer management, lifetime sales history, and store credit balance tracking', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditCustomerDialog(context, ref),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Add New Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar & Outstanding Credit Filter Chip
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
                      hintText: 'Search customer by name, phone, or email...',
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) {
                      ref.read(customerSearchQueryProvider.notifier).state = val;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              FilterChip(
                label: const Text('Outstanding Credit Only', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: creditOnly,
                selectedColor: AppColors.dangerLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (val) {
                  ref.read(customerCreditFilterProvider.notifier).state = val;
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Customer Directory Data Table Container with Horizontal Scrollbar Slider
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
                child: customersAsync.when(
                  data: (customers) {
                    if (customers.isEmpty) {
                      return const EmptyStateWidget(
                        title: 'No customers found',
                        description: 'Register customers to track lifetime purchases and store credit',
                        icon: Icons.people_alt_rounded,
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final minTableWidth = 960.0;
                        final tableWidth = math.max(constraints.maxWidth, minTableWidth);
                        final calcSpacing = (tableWidth - 750) / 6;
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
                                  dividerColor: const Color(0xFFE2E8F0),
                                ),
                                child: DataTable(
                                  columnSpacing: columnSpacing,
                                  horizontalMargin: 12,
                                dividerThickness: 1,
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)),
                                dataRowMinHeight: 56,
                                dataRowMaxHeight: 64,
                                columns: const [
                                  DataColumn(label: Text('Customer Name')),
                                  DataColumn(label: Text('Phone Number')),
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Address')),
                                  DataColumn(label: Text('Total Lifetime Spend')),
                                  DataColumn(label: Text('Credit Balance')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: customers.map((c) {
                                  final hasCredit = c.creditBalance > 0;

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: AppColors.primaryLight,
                                              child: Text(
                                                c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              c.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          c.phone.isNotEmpty ? c.phone : '—',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          c.email.isNotEmpty ? c.email : '—',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          c.address.isNotEmpty ? c.address : '—',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          Formatters.currency(c.totalPurchases, symbol: currency),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: hasCredit ? AppColors.dangerLight : AppColors.successLight,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            Formatters.currency(c.creditBalance, symbol: currency),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: hasCredit ? AppColors.danger : const Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (hasCredit) ...[
                                              OutlinedButton.icon(
                                                onPressed: () => _showPayCreditDialog(context, ref, c, currency),
                                                icon: const Icon(Icons.attach_money_rounded, size: 14, color: AppColors.success),
                                                label: const Text('Pay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  side: const BorderSide(color: AppColors.success),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            IconButton(
                                              icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.info),
                                              tooltip: 'Edit Customer',
                                              onPressed: () => _showAddEditCustomerDialog(context, ref, existing: c),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                                              tooltip: 'Delete Customer',
                                              onPressed: () async {
                                                final confirmed = await ConfirmationDialog.show(
                                                  context,
                                                  title: 'Delete Customer',
                                                  message: 'Are you sure you want to delete customer ${c.name}?',
                                                );
                                                if (confirmed == true) {
                                                  await ref.read(customerActionProvider.notifier).deleteCustomer(c.id);
                                                  if (context.mounted) {
                                                    ToastHelper.showSuccess(context, 'Customer deleted');
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

  void _showAddEditCustomerDialog(BuildContext context, WidgetRef ref, {Customer? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existing == null ? 'Add New Customer' : 'Edit Customer Info', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Customer Full Name *',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address (Optional)',
                  prefixIcon: Icon(Icons.email_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address (Optional)',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();

              if (name.isEmpty) {
                ToastHelper.showError(context, 'Customer Name is required');
                return;
              }
              if (phone.isEmpty) {
                ToastHelper.showError(context, 'Phone Number is required');
                return;
              }

              const uuid = Uuid();
              final customer = Customer(
                id: existing?.id ?? 'cust-${uuid.v4().substring(0, 8)}',
                name: name,
                phone: phone,
                email: emailCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                createdAt: existing?.createdAt ?? DateTime.now(),
              );

              if (existing == null) {
                await ref.read(customerActionProvider.notifier).addCustomer(customer);
              } else {
                await ref.read(customerActionProvider.notifier).updateCustomer(customer);
              }

              if (context.mounted) {
                Navigator.of(context).pop();
                ToastHelper.showSuccess(context, 'Customer saved successfully');
              }
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }

  void _showPayCreditDialog(BuildContext context, WidgetRef ref, Customer customer, String currency) {
    final amountCtrl = TextEditingController(text: customer.creditBalance.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Collect Credit Payment - ${customer.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Current Outstanding Debt: ${Formatters.currency(customer.creditBalance, symbol: currency)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Payment Received Amount',
                  prefixIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(
                      currency,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0.0;
              if (amount <= 0) return;

              await ref.read(customerActionProvider.notifier).payCredit(customer.id, amount);
              if (context.mounted) {
                Navigator.of(context).pop();
                ToastHelper.showSuccess(context, 'Credit payment collected!');
              }
            },
            child: const Text('Confirm Payment Received'),
          ),
        ],
      ),
    );
  }
}
