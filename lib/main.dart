import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'core/database/database_helper.dart';
import 'core/database/demo_seeder.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/sidebar_navigation.dart';
import 'core/widgets/top_app_bar.dart';
import 'domain/providers/navigation_provider.dart';
import 'domain/providers/settings_provider.dart';
import 'presentation/pos/pos_screen.dart';
import 'presentation/returns/returns_screen.dart';
import 'presentation/dashboard/dashboard_screen.dart';
import 'presentation/inventory/inventory_screen.dart';
import 'presentation/sales/sales_screen.dart';
import 'presentation/customers/customers_screen.dart';
import 'presentation/reports/reports_screen.dart';
import 'presentation/settings/settings_screen.dart';
import 'presentation/scanner/scanner_screen.dart';
import 'presentation/mobile/mobile_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for Web vs Desktop offline
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Purge pre-seeded demo data if present
  try {
    final db = await DatabaseHelper.instance.database;
    await DemoSeeder.purgeDemoData(db);
  } catch (e) {
    debugPrint('Database initialization / seeder warning: $e');
  }

  runApp(
    const ProviderScope(
      child: AhmadPharmacyApp(),
    ),
  );
}

class AhmadPharmacyApp extends ConsumerWidget {
  const AhmadPharmacyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsVal = ref.watch(settingsProvider);
    final isDark = settingsVal.value?.isDarkMode ?? false;

    return MaterialApp(
      title: 'Ahmad Pharmacy POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const MainShellScreen(),
    );
  }
}

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobilePlatform = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
        final isNarrowScreen = constraints.maxWidth < 768;

        // Dedicated Mobile Shell (QR Scanner, Stock, and Bill) for mobile phones & narrow screens
        if (isMobilePlatform || isNarrowScreen) {
          return const MobileShellScreen();
        }

        final navState = ref.watch(navigationProvider);

        return Scaffold(
          body: Row(
            children: [
              // Pinned Left Sidebar Navigation
              const SidebarNavigation(),

              // Main Screen Body Container
              Expanded(
                child: Column(
                  children: [
                    // Top Header Bar
                    const TopAppBar(),

                    // Active Module View Screen
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _buildCurrentScreen(navState.currentScreen),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentScreen(NavScreen screen) {
    switch (screen) {
      case NavScreen.pos:
        return const PosScreen(key: ValueKey('pos'));
      case NavScreen.returns:
        return const ReturnsScreen(key: ValueKey('returns'));
      case NavScreen.dashboard:
        return const DashboardScreen(key: ValueKey('dashboard'));
      case NavScreen.inventory:
      case NavScreen.purchases:
      case NavScreen.medicines:
        return const InventoryScreen(key: ValueKey('inventory'));
      case NavScreen.sales:
        return const SalesScreen(key: ValueKey('sales'));
      case NavScreen.customers:
        return const CustomersScreen(key: ValueKey('customers'));
      case NavScreen.reports:
        return const ReportsScreen(key: ValueKey('reports'));
      case NavScreen.settings:
        return const SettingsScreen(key: ValueKey('settings'));
      case NavScreen.scanner:
        return const ScannerScreen(key: ValueKey('scanner'));
    }
  }
}
