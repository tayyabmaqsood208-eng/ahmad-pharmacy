import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ahmad_pharmacy_pos/core/network/scanner_network_service.dart';
import 'package:ahmad_pharmacy_pos/data/models/medicine.dart';
import 'package:ahmad_pharmacy_pos/data/repositories/medicine_repository.dart';

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
    test('ScannerServer starts, accepts pairing from ScannerClient, and transmits scan event', () async {
      final server = ScannerServer();
      final client = ScannerClient();

      final serverStarted = await server.start(preferredPort: 18089);
      expect(serverStarted, isTrue);
      expect(server.isRunning, isTrue);

      final token = server.pairingToken;
      expect(token.isNotEmpty, isTrue);

      final scanCompleter = Completer<String>();
      server.onScanReceived = (barcode, sendAck) {
        scanCompleter.complete(barcode);
        sendAck({
          'status': 'success',
          'medicineName': 'Panadol 500mg',
          'price': 35.0,
        });
      };

      // Connect client
      final connected = await client.connect(
        ip: '127.0.0.1',
        port: server.port,
        token: token,
        deviceName: 'Test Phone Scanner',
      );

      expect(connected, isTrue);
      // Wait briefly for handshake acknowledgment
      await Future.delayed(const Duration(milliseconds: 150));
      expect(client.isConnected, isTrue);
      expect(server.pairedDevice, isNotNull);
      expect(server.pairedDevice!.name, 'Test Phone Scanner');

      // Send barcode scan from client
      final sent = client.sendScan('8964000123456');
      expect(sent, isTrue);

      final receivedBarcode = await scanCompleter.future.timeout(const Duration(seconds: 3));
      expect(receivedBarcode, '8964000123456');

      // Wait for ack
      await Future.delayed(const Duration(milliseconds: 150));
      expect(client.recentLogs.isNotEmpty, isTrue);
      expect(client.recentLogs.first.barcode, '8964000123456');
      expect(client.recentLogs.first.title, 'Panadol 500mg');
      expect(client.recentLogs.first.isSuccess, isTrue);

      // Test Single Active Device Limit: 2nd client should be rejected
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
  });
}
