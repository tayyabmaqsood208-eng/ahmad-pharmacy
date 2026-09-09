import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Batch;
import 'package:ahmad_pharmacy_pos/core/network/scanner_network_service.dart';
import 'package:ahmad_pharmacy_pos/data/models/medicine.dart';
import 'package:ahmad_pharmacy_pos/data/models/batch.dart';
import 'package:ahmad_pharmacy_pos/data/models/stock_adjustment.dart';
import 'package:ahmad_pharmacy_pos/data/repositories/medicine_repository.dart';
import 'package:ahmad_pharmacy_pos/data/repositories/inventory_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Barcode Database & Repository Tests', () {
    test('Medicine model supports barcode and getMedicineByBarcode resolves by barcode or SKU', () async {
      final repo = MedicineRepository();

      final medWithBarcode = Medicine(
        id: 'test_barcode_med_1',
        name: 'Panadol Advance 500mg',
        genericName: 'Paracetamol',
        sku: 'PAN-500',
        barcode: '8964000123456',
        category: 'Analgesics',
        dosageForm: 'Tablet',
        unit: 'Box',
        packSize: 10,
        minStock: 10,
        location: 'A-1',
        defaultPrice: 35.0,
        defaultCostPrice: 25.0,
      );

      await repo.addMedicine(medWithBarcode);

      // 1. Lookup by exact barcode
      final foundByBarcode = await repo.getMedicineByBarcode('8964000123456');
      expect(foundByBarcode, isNotNull);
      expect(foundByBarcode!.id, 'test_barcode_med_1');
      expect(foundByBarcode.barcode, '8964000123456');

      // 2. Lookup by SKU (fallback when barcode is SKU)
      final foundBySku = await repo.getMedicineByBarcode('PAN-500');
      expect(foundBySku, isNotNull);
      expect(foundBySku!.id, 'test_barcode_med_1');

      // 3. Lookup non-existent barcode
      final notFound = await repo.getMedicineByBarcode('9999999999999');
      expect(notFound, isNull);

      // Clean up
      await repo.deleteMedicine('test_barcode_med_1');
    });
  });

  group('Offline WebSocket Scanner Pairing & Pipeline Tests', () {
    test('ScannerServer supports Sale Mode and Stock Mode with quantity and USB loopback', () async {
      final server = ScannerServer();
      final client = ScannerClient();

      final serverStarted = await server.start(preferredPort: 18089);
      expect(serverStarted, isTrue);
      expect(server.isRunning, isTrue);

      final token = server.pairingToken;
      expect(token.isNotEmpty, isTrue);

      String? lastReceivedBarcode;
      String? lastReceivedMode;
      int? lastReceivedQuantity;

      server.onScanReceived = (barcode, mode, quantity, sendAck) {
        lastReceivedBarcode = barcode;
        lastReceivedMode = mode;
        lastReceivedQuantity = quantity;

        if (mode == 'stock') {
          sendAck({
            'status': 'success',
            'medicineName': 'Amoxicillin 250mg',
            'newStock': 150,
          });
        } else {
          sendAck({
            'status': 'success',
            'medicineName': 'Panadol 500mg',
            'price': 35.0,
          });
        }
      };

      // Connect client via USB Loopback (127.0.0.1)
      final connected = await client.connect(
        ip: '127.0.0.1',
        port: server.port,
        token: token,
        deviceName: 'Test Phone Scanner (USB)',
      );

      expect(connected, isTrue);
      await Future.delayed(const Duration(milliseconds: 150));
      expect(client.isConnected, isTrue);
      expect(server.pairedDevice, isNotNull);
      expect(server.pairedDevice!.name, 'Test Phone Scanner (USB)');

      // --- TEST 1: SALE MODE SCAN (Cart Addition) ---
      final saleSent = client.sendScan('8964000123456', mode: 'sale', quantity: 1);
      expect(saleSent, isTrue);

      await Future.delayed(const Duration(milliseconds: 200));
      expect(lastReceivedBarcode, '8964000123456');
      expect(lastReceivedMode, 'sale');
      expect(lastReceivedQuantity, 1);

      expect(client.recentLogs.isNotEmpty, isTrue);
      final saleLog = client.recentLogs.first;
      expect(saleLog.barcode, '8964000123456');
      expect(saleLog.mode, 'sale');
      expect(saleLog.price, 35.0);
      expect(saleLog.isSuccess, isTrue);

      // --- TEST 2: STOCK MODE SCAN (Inventory Restock) ---
      final stockSent = client.sendScan('8964000999999', mode: 'stock', quantity: 50);
      expect(stockSent, isTrue);

      await Future.delayed(const Duration(milliseconds: 200));
      expect(lastReceivedBarcode, '8964000999999');
      expect(lastReceivedMode, 'stock');
      expect(lastReceivedQuantity, 50);

      expect(client.recentLogs.length, 2);
      final stockLog = client.recentLogs.first;
      expect(stockLog.barcode, '8964000999999');
      expect(stockLog.mode, 'stock');
      expect(stockLog.quantity, 50);
      expect(stockLog.newStock, 150);
      expect(stockLog.isSuccess, isTrue);

      // --- TEST 3: Single Active Device Limit ---
      final client2 = ScannerClient();
      await client2.connect(
        ip: '127.0.0.1',
        port: server.port,
        token: token,
        deviceName: 'Second Phone (Should Be Rejected)',
      );
      await Future.delayed(const Duration(milliseconds: 150));
      expect(client2.isConnected, isFalse);

      // Clean up
      client.disconnect();
      client2.disconnect();
      await server.stop();
    });

    test('Inventory repository supports stock adjustments for restock auditing', () async {
      final invRepo = InventoryRepository();
      final medRepo = MedicineRepository();

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final testMedId = 'test_restock_med_$timestamp';
      final testBatchId = 'batch_test_$timestamp';
      final testAdjId = 'adj_test_$timestamp';

      final testMed = Medicine(
        id: testMedId,
        name: 'Flagyl 400mg',
        genericName: 'Metronidazole',
        sku: 'FLA-$timestamp',
        barcode: '8964000$timestamp',
        category: 'Antibiotics',
        dosageForm: 'Tablet',
        unit: 'Box',
        packSize: 10,
        minStock: 10,
        location: 'B-2',
        defaultPrice: 40.0,
        defaultCostPrice: 28.0,
        totalStock: 20,
      );

      await medRepo.addMedicine(testMed);

      try {
        final initialBatch = Batch(
          id: testBatchId,
          medicineId: testMed.id,
          batchNumber: 'B-$timestamp',
          expiryDate: DateTime.now().add(const Duration(days: 365)),
          quantity: 20,
          buyPrice: 28.0,
          sellPrice: 40.0,
          receivedDate: DateTime.now(),
        );
        await invRepo.addBatch(initialBatch);

        final adjustment = StockAdjustment(
          id: testAdjId,
          medicineId: testMed.id,
          medicineName: testMed.name,
          batchId: initialBatch.id,
          batchNumber: initialBatch.batchNumber,
          quantityChange: 50,
          adjustmentType: 'Add',
          reason: 'Restock (Mobile Scanner)',
          createdAt: DateTime.now(),
          notes: 'Restocked via mobile scanner test (50 units)',
        );

        await invRepo.addStockAdjustment(adjustment, updateBatchQuantity: true);
        await medRepo.updateMedicine(testMed.copyWith(totalStock: testMed.totalStock + 50));

        // Verify updated medicine total stock in DB
        final updatedMed = await medRepo.getMedicineById(testMed.id);
        expect(updatedMed, isNotNull);
        expect(updatedMed!.totalStock, 70);

        // Verify adjustment log recorded
        final adjustments = await invRepo.getStockAdjustments();
        expect(adjustments.any((a) => a.id == testAdjId && a.quantityChange == 50), isTrue);
      } finally {
        // Clean up
        await medRepo.deleteMedicine(testMed.id);
      }
    });
  });
}
