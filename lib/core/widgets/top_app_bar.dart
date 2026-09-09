import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/navigation_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';

class TopAppBar extends ConsumerWidget {
  const TopAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);
    final settingsVal = ref.watch(settingsProvider);
    final isDark = settingsVal.value?.isDarkMode ?? false;
    final screenTitle = _getScreenTitle(navState.currentScreen);

    final borderCol = isDark ? AppColors.borderDark : AppColors.border;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkBg : AppColors.cardBg,
        border: Border(bottom: BorderSide(color: borderCol, width: 1)),
      ),
      child: Row(
        children: [
          // Sidebar Toggle Button
          IconButton(
            icon: Icon(
              navState.isSidebarCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
              size: 22,
              color: isDark ? Colors.white70 : AppColors.textPrimary,
            ),
            tooltip: navState.isSidebarCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
            onPressed: () => ref.read(navigationProvider.notifier).toggleSidebar(),
          ),
          const SizedBox(width: 8),

          // Screen Title & Subtitle
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  screenTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  Formatters.date(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // System Status Badge: Offline SQLite Active (visible on wider screens)
          if (MediaQuery.of(context).size.width > 680)
            Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Offline DB',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Theme Mode Toggle
          IconButton(
            onPressed: () => ref.read(settingsProvider.notifier).toggleDarkMode(),
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
              color: isDark ? Colors.amber : AppColors.textSecondary,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),

          if (navState.currentScreen != NavScreen.pos) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => ref.read(navigationProvider.notifier).navigateTo(NavScreen.pos),
              icon: const Icon(Icons.shopping_cart_rounded, size: 14),
              label: const Text('Open POS', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getScreenTitle(NavScreen screen) {
    switch (screen) {
      case NavScreen.pos:
        return 'Point of Sale (POS)';
      case NavScreen.returns:
        return 'Sales Returns';
      case NavScreen.dashboard:
        return 'Pharmacy Dashboard';
      case NavScreen.inventory:
        return 'Inventory & Batches';
      case NavScreen.medicines:
        return 'Medicine Catalog';
      case NavScreen.purchases:
        return 'Stock Purchases';
      case NavScreen.sales:
        return 'Sales History & Invoices';
      case NavScreen.customers:
        return 'Customer Directory & Credit';
      case NavScreen.reports:
        return 'Reports & Analytics';
      case NavScreen.settings:
        return 'System Settings';
    }
  }
}
