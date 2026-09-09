import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/navigation_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../theme/app_colors.dart';

class SidebarNavigation extends ConsumerWidget {
  const SidebarNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationProvider);
    final settingsVal = ref.watch(settingsProvider);
    final isDark = settingsVal.value?.isDarkMode ?? false;
    final isCollapsed = navState.isSidebarCollapsed;

    final bg = isDark ? AppColors.sidebarDarkBg : AppColors.sidebarBg;
    final borderCol = isDark ? AppColors.borderDark : AppColors.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 76 : 240,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: borderCol, width: 1)),
      ),
      child: Column(
        children: [
          // Header / Logo
          _buildHeader(context, isCollapsed, settingsVal.value?.pharmacyName ?? 'Ahmad Pharmacy'),
          const SizedBox(height: 8),

          // Nav Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                _buildSectionHeader(isCollapsed, 'GENERAL'),
                _buildNavItem(
                  ref: ref,
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  screen: NavScreen.dashboard,
                  activeScreen: navState.currentScreen,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  ref: ref,
                  icon: Icons.shopping_cart_rounded,
                  label: 'POS (Billing)',
                  screen: NavScreen.pos,
                  activeScreen: navState.currentScreen,
                  isCollapsed: isCollapsed,
                  badgeText: 'HOT',
                ),

                const SizedBox(height: 14),

                _buildSectionHeader(isCollapsed, 'STOCK & BUYING'),
                _buildNavItem(
                  ref: ref,
                  icon: Icons.inventory_2_rounded,
                  label: 'Inventory',
                  screen: NavScreen.inventory,
                  activeScreen: navState.currentScreen,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  ref: ref,
                  icon: Icons.assignment_return_rounded,
                  label: 'Returns',
                  screen: NavScreen.returns,
                  activeScreen: navState.currentScreen,
                  isCollapsed: isCollapsed,
                ),

                const SizedBox(height: 14),

                _buildSectionHeader(isCollapsed, 'REVENUE'),
                _buildNavItem(
                  ref: ref,
                  icon: Icons.receipt_long_rounded,
                  label: 'Sales History',
                  screen: NavScreen.sales,
                  activeScreen: navState.currentScreen,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  ref: ref,
                  icon: Icons.people_alt_rounded,
                  label: 'Customers',
                  screen: NavScreen.customers,
                  activeScreen: navState.currentScreen,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  ref: ref,
                  icon: Icons.bar_chart_rounded,
                  label: 'Reports & Stats',
                  screen: NavScreen.reports,
                  activeScreen: navState.currentScreen,
                  isCollapsed: isCollapsed,
                ),

                const SizedBox(height: 14),

                _buildSectionHeader(isCollapsed, 'SYSTEM'),
                _buildNavItem(
                  ref: ref,
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  screen: NavScreen.settings,
                  activeScreen: navState.currentScreen,
                  isCollapsed: isCollapsed,
                ),
              ],
            ),
          ),

          // Collapse Pinned Button at Bottom
          Divider(height: 1, color: borderCol),
          InkWell(
            onTap: () => ref.read(navigationProvider.notifier).toggleSidebar(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Row(
                mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                children: [
                  if (!isCollapsed)
                    const Expanded(
                      child: Text(
                        'Collapse Sidebar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Icon(
                    isCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isCollapsed, String appName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 22),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Pharmacy POS',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(bool isCollapsed, String title) {
    if (isCollapsed) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required WidgetRef ref,
    required IconData icon,
    required String label,
    required NavScreen screen,
    required NavScreen activeScreen,
    required bool isCollapsed,
    String? badgeText,
  }) {
    final isActive = screen == activeScreen;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => ref.read(navigationProvider.notifier).navigateTo(screen),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 12 : 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: isActive ? Colors.white : AppColors.textSecondary,
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? Colors.white : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white.withValues(alpha: 0.25) : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
