import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ahmad_pharmacy_pos/data/models/medicine.dart';
import 'package:ahmad_pharmacy_pos/domain/providers/pos_cart_provider.dart';

void main() {
  group('Tablet Default Unit Selection & Calculation Tests', () {
    final testMedicine = Medicine(
      id: '1',
      name: 'Pendole',
      genericName: 'pendaole',
      sku: 'PEN-001',
      category: 'Analgesic',
      dosageForm: 'Tablet',
      unit: 'Box',
      packSize: 10,
      minStock: 5,
      location: 'Shelf A',
      defaultPrice: 120.0,
      defaultCostPrice: 80.0,
      totalStock: 7,
      requiresPrescription: false,
      productType: 'Medicine',
    );

    test('Medicine identifies as multi-pack and calculates tablet price', () {
      expect(testMedicine.isTabletOrPack, isTrue);
      expect(testMedicine.effectivePackSize, 10);
      final tabPrice = testMedicine.defaultPrice / testMedicine.effectivePackSize;
      expect(tabPrice, 12.0);
    });

    test('POS Cart adds Single Tablet by default (isFullBox: false)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(posCartProvider.notifier);

      // Default addition is Single Tablet (isFullBox: false)
      notifier.addItem(testMedicine, isFullBox: false);

      final state = container.read(posCartProvider);
      expect(state.items.length, 1);
      final item = state.items.first;

      expect(item.isFullBox, isFalse);
      expect(item.unitLabel, 'Tablet');
      expect(item.unitPrice, 12.0);
      expect(item.subtotal, 12.0);
    });

    test('POS Cart can toggle between Tablet and Box', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(posCartProvider.notifier);

      // Add default single tablet
      notifier.addItem(testMedicine, isFullBox: false);
      expect(container.read(posCartProvider).items.first.unitPrice, 12.0);

      // Toggle to Full Box
      notifier.toggleItemUnit(0);
      final boxItem = container.read(posCartProvider).items.first;
      expect(boxItem.isFullBox, isTrue);
      expect(boxItem.unitLabel, 'Box');
      expect(boxItem.unitPrice, 120.0);
      expect(boxItem.subtotal, 120.0);

      // Toggle back to Tablet
      notifier.toggleItemUnit(0);
      final tabItem = container.read(posCartProvider).items.first;
      expect(tabItem.isFullBox, isFalse);
      expect(tabItem.unitLabel, 'Tablet');
      expect(tabItem.unitPrice, 12.0);
      expect(tabItem.subtotal, 12.0);
    });
  });
}
