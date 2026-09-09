import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Batch;
import 'package:ahmad_pharmacy_pos/main.dart';
import 'package:ahmad_pharmacy_pos/core/widgets/sidebar_navigation.dart';
import 'package:ahmad_pharmacy_pos/presentation/mobile/mobile_shell_screen.dart';
import 'package:ahmad_pharmacy_pos/presentation/mobile/mobile_stock_screen.dart';
import 'package:ahmad_pharmacy_pos/presentation/mobile/mobile_bill_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Mobile Responsiveness & Mobile Phone Assistant Tests', () {
    testWidgets('On mobile screen (width < 768), displays MobileShellScreen without desktop sidebar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844); // iPhone 13/14 portrait dimensions
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: AhmadPharmacyApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify MobileShellScreen is present
      expect(find.byType(MobileShellScreen), findsOneWidget);

      // Verify desktop SidebarNavigation is NOT present on mobile
      expect(find.byType(SidebarNavigation), findsNothing);

      // Verify the 3 dedicated mobile destinations exist
      expect(find.text('QR Scanner'), findsOneWidget);
      expect(find.text('Stock'), findsOneWidget);
      expect(find.text('Create Bill'), findsOneWidget);

      // Tap on 'Stock' bottom navigation tab
      await tester.tap(find.text('Stock'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MobileStockScreen), findsOneWidget);
      expect(find.text('Catalog Stock'), findsOneWidget);
      expect(find.text('Add Med'), findsOneWidget);

      // Tap on 'Create Bill' bottom navigation tab
      await tester.tap(find.text('Create Bill'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MobileBillScreen), findsOneWidget);
      expect(find.text('Active Sale Bill'), findsOneWidget);
      expect(find.text('Walk-in Customer (Tap to change)'), findsOneWidget);
    });

    testWidgets('On desktop screen (width >= 768), displays desktop shell with SidebarNavigation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: AhmadPharmacyApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Desktop SidebarNavigation is present
      expect(find.byType(SidebarNavigation), findsOneWidget);
      expect(find.byType(MobileShellScreen), findsNothing);
    });
  });
}
