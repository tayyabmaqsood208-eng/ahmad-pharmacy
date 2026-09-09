import 'dart:io' show Platform, Directory, File, Process;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/providers/report_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/utils/toast_helper.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedRange = '30 Days';
  DateTimeRange? _customDateRange;

  @override
  Widget build(BuildContext context) {
    final pnlAsync = ref.watch(profitAndLossProvider);
    final topMedsAsync = ref.watch(topSellingMedicinesProvider);
    final valuationAsync = ref.watch(stockValuationProvider);
    final settingsVal = ref.watch(settingsProvider).value;
    final currency = settingsVal?.currencySymbol ?? 'Rs';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Timeframe Filter Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Financial Reports & Business Intelligence',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Executive overview of revenue, COGS, margins, and inventory valuation',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              // Export Excel & Date Filter Controls
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Export Excel Button
                    ElevatedButton.icon(
                      onPressed: () => _exportReportToExcel(context, currency),
                      icon: const Icon(Icons.file_download_rounded, size: 16),
                      label: const Text(
                        'Export Excel (CSV)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Custom Date Range Picker Button
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          initialDateRange:
                              _customDateRange ??
                              DateTimeRange(
                                start: DateTime.now().subtract(
                                  const Duration(days: 30),
                                ),
                                end: DateTime.now(),
                              ),
                        );
                        if (picked != null) {
                          setState(() {
                            _customDateRange = picked;
                            _selectedRange = 'Custom';
                          });
                        }
                      },
                      icon: const Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        _customDateRange != null
                            ? '${Formatters.date(_customDateRange!.start)} - ${Formatters.date(_customDateRange!.end)}'
                            : 'Custom Date',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Quick Chips
                    ...['Today', '7 Days', '30 Days', 'All Time'].map((range) {
                      final isSel = _selectedRange == range;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: ChoiceChip(
                          label: Text(range),
                          selected: isSel,
                          selectedColor: AppColors.primary,
                          backgroundColor: const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isSel ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSel
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedRange = range;
                              _customDateRange = null;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // PnL Key Metrics Row
          pnlAsync.when(
            data: (pnl) {
              final grossSales = pnl['grossSales'] as double;
              final cogs = pnl['cogs'] as double;
              final grossProfit = pnl['grossProfit'] as double;
              final refunds = pnl['totalRefunds'] as double;

              return LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 4;
                  if (constraints.maxWidth < 850) {
                    crossAxisCount = 2;
                  }

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 2.1,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: [
                      StatCard(
                        title: 'Gross Revenue',
                        value: Formatters.currency(
                          grossSales,
                          symbol: currency,
                        ),
                        subtitle: 'Completed sales total',
                        icon: Icons.attach_money_rounded,
                        iconColor: AppColors.primary,
                        iconBgColor: AppColors.primaryLight,
                      ),
                      StatCard(
                        title: 'Sales Refunds',
                        value: Formatters.currency(refunds, symbol: currency),
                        subtitle: 'Returned sales total',
                        icon: Icons.assignment_return_rounded,
                        iconColor: AppColors.danger,
                        iconBgColor: AppColors.dangerLight,
                      ),
                      StatCard(
                        title: 'Cost of Goods Sold',
                        value: Formatters.currency(cogs, symbol: currency),
                        subtitle: 'Inventory cost total',
                        icon: Icons.shopping_bag_rounded,
                        iconColor: AppColors.info,
                        iconBgColor: AppColors.infoLight,
                      ),
                      StatCard(
                        title: 'Gross Profit Margin',
                        value: Formatters.currency(
                          grossProfit,
                          symbol: currency,
                        ),
                        subtitle: 'Revenue minus COGS',
                        icon: Icons.trending_up_rounded,
                        iconColor: AppColors.success,
                        iconBgColor: AppColors.successLight,
                      ),
                    ],
                  );
                },
              );
            },
            loading: () => const SkeletonLoader(height: 100),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),

          const SizedBox(height: 20),

          // Two-Column Section: Top Best Sellers + Inventory Valuation
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Top 5 Best Selling Medicines
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Top 5 Best Selling Medicines',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        topMedsAsync.when(
                          data: (topMeds) {
                            if (topMeds.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Text(
                                    'No sales records available yet',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: topMeds.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final med = topMeds[index];
                                final qty = med['quantity'] as int;
                                final rev = med['revenue'] as double;
                                final rank = index + 1;

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: rank == 1
                                              ? AppColors.primary
                                              : const Color(0xFFE2E8F0),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '#$rank',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: rank == 1
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              med['name'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$qty units sold',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        Formatters.currency(
                                          rev,
                                          symbol: currency,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const SkeletonLoader(height: 180),
                          error: (err, _) => Center(child: Text('Error: $err')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Right Column: Stock Inventory Valuation
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.infoLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: AppColors.info,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Stock Inventory Valuation',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        valuationAsync.when(
                          data: (valuation) {
                            final totalCost = valuation['totalCost'] ?? 0.0;
                            final totalRetail = valuation['totalRetail'] ?? 0.0;
                            final profit = valuation['potentialProfit'] ?? 0.0;

                            return Column(
                              children: [
                                _buildValuationTile(
                                  'Total Inventory Cost Value',
                                  Formatters.currency(
                                    totalCost,
                                    symbol: currency,
                                  ),
                                  Icons.inventory_2_rounded,
                                  AppColors.textSecondary,
                                ),
                                const SizedBox(height: 10),
                                _buildValuationTile(
                                  'Total Retail Value (Gross)',
                                  Formatters.currency(
                                    totalRetail,
                                    symbol: currency,
                                  ),
                                  Icons.sell_rounded,
                                  AppColors.primary,
                                  isPrimary: true,
                                ),
                                const SizedBox(height: 10),
                                _buildValuationTile(
                                  'Potential Gross Profit Margin',
                                  Formatters.currency(profit, symbol: currency),
                                  Icons.trending_up_rounded,
                                  AppColors.success,
                                  isSuccess: true,
                                ),
                              ],
                            );
                          },
                          loading: () => const SkeletonLoader(height: 150),
                          error: (err, _) => Center(child: Text('Error: $err')),
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
    );
  }

  Widget _buildValuationTile(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isPrimary = false,
    bool isSuccess = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.primaryLight.withValues(alpha: 0.5)
            : (isSuccess
                  ? AppColors.successLight.withValues(alpha: 0.5)
                  : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary
              ? AppColors.primary.withValues(alpha: 0.3)
              : (isSuccess
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isPrimary ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: isPrimary
                  ? AppColors.primary
                  : (isSuccess
                        ? const Color(0xFF15803D)
                        : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReportToExcel(
    BuildContext context,
    String currency,
  ) async {
    try {
      final pnl = ref.read(profitAndLossProvider).value;
      final topMeds = ref.read(topSellingMedicinesProvider).value;
      final valuation = ref.read(stockValuationProvider).value;

      final csvContent = StringBuffer();
      csvContent.writeln('AHMAD PHARMACY - FINANCIAL REPORT EXPORT');
      csvContent.writeln('Generated Date,${DateTime.now().toIso8601String()}');
      csvContent.writeln('Selected Range,$_selectedRange');
      csvContent.writeln('');

      csvContent.writeln('KEY FINANCIAL METRICS');
      csvContent.writeln('Metric,Amount');
      csvContent.writeln('Gross Revenue,${pnl?['grossSales'] ?? 0.0}');
      csvContent.writeln('Sales Refunds,${pnl?['totalRefunds'] ?? 0.0}');
      csvContent.writeln('Cost of Goods Sold (COGS),${pnl?['cogs'] ?? 0.0}');
      csvContent.writeln('Gross Profit Margin,${pnl?['grossProfit'] ?? 0.0}');
      csvContent.writeln('');

      csvContent.writeln('STOCK INVENTORY VALUATION');
      csvContent.writeln(
        'Total Inventory Cost Value,${valuation?['totalCost'] ?? 0.0}',
      );
      csvContent.writeln(
        'Total Retail Value (Gross),${valuation?['totalRetail'] ?? 0.0}',
      );
      csvContent.writeln(
        'Potential Gross Profit Margin,${valuation?['potentialProfit'] ?? 0.0}',
      );
      csvContent.writeln('');

      csvContent.writeln('TOP SELLING MEDICINES');
      csvContent.writeln('Rank,Medicine Name,Quantity Sold,Total Revenue');
      if (topMeds != null) {
        for (int i = 0; i < topMeds.length; i++) {
          final med = topMeds[i];
          csvContent.writeln(
            '${i + 1},"${med['name']}",${med['quantity']},${med['revenue']}',
          );
        }
      }

      if (kIsWeb) {
        if (context.mounted) {
          ToastHelper.showSuccess(context, 'CSV Export complete');
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
      final fileName = 'Pharmacy_Financial_Report_$dateStr.csv';
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
                const Text('CSV Downloaded!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The Excel (CSV) report has been downloaded and saved directly to your system Downloads folder:',
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
        ToastHelper.showError(context, 'Export error: $e');
      }
    }
  }
}
