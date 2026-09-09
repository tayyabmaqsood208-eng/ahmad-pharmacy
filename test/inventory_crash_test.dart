import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ahmad_pharmacy_pos/main.dart';
import 'package:ahmad_pharmacy_pos/presentation/inventory/inventory_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Clicking inventory in MainShellScreen does not crash', (WidgetTester tester) async {
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
    await tester.pumpAndSettle();

    // Find Inventory in Sidebar and tap it
    final inventoryNavItem = find.text('Inventory');
    expect(inventoryNavItem, findsOneWidget);
    await tester.tap(inventoryNavItem);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(InventoryScreen), findsOneWidget);
  });
}
