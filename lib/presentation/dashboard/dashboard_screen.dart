import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import '../../domain/providers/report_provider.dart';
import '../../domain/providers/sales_provider.dart';
import '../../domain/providers/inventory_provider.dart';
import '../../domain/providers/navigation_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/stat_card.dart';
import '../../core/widgets/skeleton_loader.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final salesTrendAsync = ref.watch(salesTrendProvider);
    final recentSalesAsync = ref.watch(salesListProvider);
    final expiringBatchesAsync = ref.watch(expiringBatchesProvider);
    final settingsVal = ref.watch(settingsProvider).value;
    final currency = settingsVal?.currencySymbol ?? 'Rs';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. KPI Cards Row
          statsAsync.when(
            data: (stats) => LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 4;
                if (constraints.maxWidth < 700) {
                  crossAxisCount = 1;
                } else if (constraints.maxWidth < 1100) {
                  crossAxisCount = 2;
                }

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  children: [
                    StatCard(
                      title: "Today's Sales",
                      value: Formatters.currency(
                        stats.todaySales,
                        symbol: currency,
                      ),
                      subtitle: "${stats.todayOrders} Orders completed today",
                      icon: Icons.attach_money_rounded,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.primaryLight,
                      onTap: () => ref
                          .read(navigationProvider.notifier)
                          .navigateTo(NavScreen.sales),
                    ),
                    StatCard(
                      title: "Total Revenue",
                      value: Formatters.currency(
                        stats.totalRevenue,
                        symbol: currency,
                      ),
                      subtitle: "Lifetime gross sales",
                      icon: Icons.trending_up_rounded,
                      iconColor: AppColors.info,
                      iconBgColor: AppColors.infoLight,
                      onTap: () => ref
                          .read(navigationProvider.notifier)
                          .navigateTo(NavScreen.reports),
                    ),
                    StatCard(
                      title: "Low Stock Items",
                      value: "${stats.lowStockCount}",
                      subtitle: "Items below min threshold",
                      icon: Icons.warning_amber_rounded,
                      iconColor: AppColors.warning,
                      iconBgColor: AppColors.warningLight,
                      onTap: () => ref
                          .read(navigationProvider.notifier)
                          .navigateTo(NavScreen.inventory),
                    ),
                    StatCard(
                      title: "Expiring Soon",
                      value: "${stats.expiringCount}",
                      subtitle: "Batches expiring in 60d",
                      icon: Icons.access_time_rounded,
                      iconColor: AppColors.danger,
                      iconBgColor: AppColors.dangerLight,
                      onTap: () => ref
                          .read(navigationProvider.notifier)
                          .navigateTo(NavScreen.inventory),
                    ),
                  ],
                );
              },
            ),
            loading: () => const Row(
              children: [
                Expanded(child: SkeletonLoader(height: 100)),
                SizedBox(width: 12),
                Expanded(child: SkeletonLoader(height: 100)),
                SizedBox(width: 12),
                Expanded(child: SkeletonLoader(height: 100)),
              ],
            ),
            error: (err, _) => Center(child: Text('Error loading stats: $err')),
          ),

          const SizedBox(height: 20),

          // 2. Main Content Split (Chart + Quick Actions & Expiry Alert)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final chartCard = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sales Performance Trend (Last 7 Days)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              Icons.bar_chart_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 220,
                          child: salesTrendAsync.when(
                            data: (trend) {
                              if (trend.isEmpty) {
                                return const Center(
                                  child: Text('No sales data available yet'),
                                );
                              }

                              return BarChart(
                                BarChartData(
                                  borderData: FlBorderData(show: false),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, meta) => Text(
                                          '${value.toInt()}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final idx = value.toInt();
                                          if (idx >= 0 && idx < trend.length) {
                                            return Text(
                                              trend[idx]['label'],
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            );
                                          }
                                          return const SizedBox();
                                        },
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    rightTitles: const AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  barGroups: List.generate(trend.length, (i) {
                                    final amt = (trend[i]['amount'] as num)
                                        .toDouble();
                                    return BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: amt,
                                          color: AppColors.primary,
                                          width: 18,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              );
                            },
                            loading: () => const SkeletonLoader(height: 200),
                            error: (err, _) =>
                                Center(child: Text('Error: $err')),
                          ),
                        ),
                      ],
                    ),
                  ),
                );

              final rightColumn = Column(
                  children: [
                    // Quick Action Buttons Box
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick Action Panel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => ref
                                        .read(navigationProvider.notifier)
                                        .navigateTo(NavScreen.pos),
                                    icon: const Icon(
                                      Icons.shopping_cart_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('New Sale'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => ref
                                        .read(navigationProvider.notifier)
                                        .navigateTo(NavScreen.purchases),
                                    icon: const Icon(
                                      Icons.local_shipping_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('New Stock'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Expiring Medicines Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Expiry Alerts',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => ref
                                      .read(navigationProvider.notifier)
                                      .navigateTo(NavScreen.inventory),
                                  child: const Text('View All'),
                                ),
                              ],
                            ),
                            expiringBatchesAsync.when(
                              data: (batches) {
                                if (batches.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: Text(
                                        'No medicines expiring in the next 60 days',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  children: batches.take(3).map((b) {
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.access_time_rounded,
                                        color: AppColors.danger,
                                        size: 18,
                                      ),
                                      title: Text(
                                        'Batch ${b.batchNumber}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      subtitle: Text(
                                        Formatters.daysUntilExpiry(
                                          b.expiryDate,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.danger,
                                        ),
                                      ),
                                      trailing: Text(
                                        '${b.quantity} left',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                              loading: () => const SkeletonLoader(height: 60),
                              error: (_, _) => const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

              if (isNarrow) {
                return Column(
                  children: [
                    chartCard,
                    const SizedBox(height: 14),
                    rightColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: chartCard),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: rightColumn),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // 3. Recent Sales Ledger
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Completed Sales',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(navigationProvider.notifier)
                            .navigateTo(NavScreen.sales),
                        child: const Text('View Full Sales Ledger'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  recentSalesAsync.when(
                    data: (sales) {
                      if (sales.isEmpty) {
                        return const Center(
                          child: Text('No transactions recorded yet'),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final minTableWidth = 850.0;
                          final tableWidth = math.max(constraints.maxWidth, minTableWidth);
                          final calcSpacing = (tableWidth - 550) / 5;
                          final columnSpacing = calcSpacing > 12 ? calcSpacing : 12.0;

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: tableWidth),
                              child: DataTable(
                                columnSpacing: columnSpacing,
                                horizontalMargin: 12,
                              columns: const [
                                DataColumn(label: Text('Invoice #')),
                                DataColumn(label: Text('Customer')),
                                DataColumn(label: Text('Items')),
                                DataColumn(label: Text('Payment Method')),
                                DataColumn(label: Text('Total Amount')),
                                DataColumn(label: Text('Date & Time')),
                              ],
                              rows: sales.take(5).map((sale) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        sale.invoiceNo,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(sale.customerName)),
                                    DataCell(Text('${sale.items.length} items')),
                                    DataCell(
                                      Chip(
                                        label: Text(
                                          sale.paymentMethod,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        Formatters.currency(
                                          sale.totalAmount,
                                          symbol: currency,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(Formatters.dateTime(sale.createdAt)),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    );
                    },
                    loading: () => const SkeletonTableLoader(rows: 3),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
