import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/scanner_network_service.dart';
import '../../data/models/paired_device.dart';
import '../../data/models/batch.dart';
import '../../data/models/stock_adjustment.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/repositories/medicine_repository.dart';
import 'pos_cart_provider.dart';
import 'medicine_provider.dart';
import 'inventory_provider.dart';
import 'report_provider.dart';

// Repositories
final medicineRepoProvider = Provider((ref) => MedicineRepository());
final inventoryRepoProvider = Provider((ref) => InventoryRepository());

enum ScannerMode {
  sale,
  stock,
}

enum ScannerTransport {
  wifi,
  usb,
}

// ==========================================
// 1. POS TERMINAL WEBSOCKET SERVER PROVIDER
// ==========================================

class ScannerServerState {
  final bool isRunning;
  final int port;
  final List<String> localIps;
  final String selectedIp;
  final String pairingToken;
  final PairedDevice? pairedDevice;
  final String? lastUnknownBarcode;
  final String lastUnknownBarcodeMode;
  final int lastUnknownBarcodeQty;
  final String? lastStockRestockedMessage;

  ScannerServerState({
    this.isRunning = false,
    this.port = 8089,
    this.localIps = const [],
    this.selectedIp = '',
    this.pairingToken = '',
    this.pairedDevice,
    this.lastUnknownBarcode,
    this.lastUnknownBarcodeMode = 'sale',
    this.lastUnknownBarcodeQty = 1,
    this.lastStockRestockedMessage,
  });

  bool get hasPairedDevice => pairedDevice != null && pairedDevice!.isConnected;

  String get pairingQrData {
    final ip = selectedIp.isNotEmpty ? selectedIp : (localIps.isNotEmpty ? localIps.first : '127.0.0.1');
    final payload = ScannerPairingPayload(
      name: 'Ahmad Pharmacy Counter',
      ip: ip,
      port: port,
      token: pairingToken,
    );
    return payload.toJsonString();
  }

  ScannerServerState copyWith({
    bool? isRunning,
    int? port,
    List<String>? localIps,
    String? selectedIp,
    String? pairingToken,
    PairedDevice? pairedDevice,
    bool clearPairedDevice = false,
    String? lastUnknownBarcode,
    bool clearUnknownBarcode = false,
    String? lastUnknownBarcodeMode,
    int? lastUnknownBarcodeQty,
    String? lastStockRestockedMessage,
    bool clearStockRestockedMessage = false,
  }) {
    return ScannerServerState(
      isRunning: isRunning ?? this.isRunning,
      port: port ?? this.port,
      localIps: localIps ?? this.localIps,
      selectedIp: selectedIp ?? this.selectedIp,
      pairingToken: pairingToken ?? this.pairingToken,
      pairedDevice: clearPairedDevice ? null : (pairedDevice ?? this.pairedDevice),
      lastUnknownBarcode: clearUnknownBarcode ? null : (lastUnknownBarcode ?? this.lastUnknownBarcode),
      lastUnknownBarcodeMode: lastUnknownBarcodeMode ?? this.lastUnknownBarcodeMode,
      lastUnknownBarcodeQty: lastUnknownBarcodeQty ?? this.lastUnknownBarcodeQty,
      lastStockRestockedMessage: clearStockRestockedMessage
          ? null
          : (lastStockRestockedMessage ?? this.lastStockRestockedMessage),
    );
  }
}

class ScannerServerNotifier extends StateNotifier<ScannerServerState> {
  final Ref _ref;
  final ScannerServer _server = ScannerServer();

  ScannerServerNotifier(this._ref) : super(ScannerServerState()) {
    _initCallbacks();
  }

  void _initCallbacks() {
    _server.onDeviceChanged = (device) {
      if (mounted) {
        state = state.copyWith(
          pairedDevice: device,
          clearPairedDevice: device == null,
        );
      }
    };

    _server.onScanReceived = (barcode, mode, quantity, sendAck) async {
      await _handleIncomingScan(barcode, mode, quantity, sendAck);
    };
  }

  /// Start server on local Wi-Fi / Hotspot
  Future<bool> startServer({int port = 8089}) async {
    final success = await _server.start(preferredPort: port);
    if (success && mounted) {
      final defaultIp = _server.localIps.isNotEmpty ? _server.localIps.first : '127.0.0.1';
      state = state.copyWith(
        isRunning: true,
        port: _server.port,
        localIps: _server.localIps,
        selectedIp: defaultIp,
        pairingToken: _server.pairingToken,
        pairedDevice: _server.pairedDevice,
      );
    }
    return success;
  }

  /// Stop server
  Future<void> stopServer() async {
    await _server.stop();
    if (mounted) {
      state = state.copyWith(
        isRunning: false,
        clearPairedDevice: true,
      );
    }
  }

  void setSelectedIp(String ip) {
    state = state.copyWith(selectedIp: ip);
  }

  void disconnectDevice() {
    _server.disconnectCurrentDevice();
    state = state.copyWith(clearPairedDevice: true);
  }

  void clearUnknownBarcode() {
    state = state.copyWith(clearUnknownBarcode: true);
  }

  void clearStockRestockedMessage() {
    state = state.copyWith(clearStockRestockedMessage: true);
  }

  /// Incoming scan processor:
  /// - Sale Mode: resolves barcode -> FEFO batch -> adds to active POS cart
  /// - Stock Mode: increments medicine totalStock in DB and writes StockAdjustment audit log without touching cart
  Future<void> _handleIncomingScan(
    String barcode,
    String mode,
    int quantity,
    Function(Map<String, dynamic>) sendAck,
  ) async {
    final medRepo = _ref.read(medicineRepoProvider);
    final invRepo = _ref.read(inventoryRepoProvider);
    final cartNotifier = _ref.read(posCartProvider.notifier);

    // 1. Lookup medicine in offline local SQLite database
    final medicine = await medRepo.getMedicineByBarcode(barcode);

    if (medicine == null) {
      // Unrecognized barcode
      debugPrint('[ScannerServer] Unknown barcode ($mode, qty: $quantity) scanned: $barcode');
      if (mounted) {
        state = state.copyWith(
          lastUnknownBarcode: barcode,
          lastUnknownBarcodeMode: mode,
          lastUnknownBarcodeQty: quantity,
        );
      }
      sendAck({
        'status': 'unknown',
        'message': 'Unrecognized Barcode',
        'mode': mode,
        'quantity': quantity,
      });
      return;
    }

    // 2. Resolve FEFO batch (earliest expiring with stock > 0)
    Batch? selectedBatch;
    String? warning;

    try {
      final batches = await invRepo.getBatchesForMedicine(medicine.id);
      final activeBatches = batches.where((b) => b.quantity > 0).toList();
      activeBatches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

      if (activeBatches.isNotEmpty) {
        selectedBatch = activeBatches.first;
        if (selectedBatch.isExpired) {
          warning = 'Warning: Earliest batch is expired!';
        } else if (selectedBatch.isExpiringSoon) {
          warning = 'Warning: Medicine expiring soon';
        }
      } else if (mode == 'sale') {
        warning = 'Warning: No batch stock recorded';
      }
    } catch (e) {
      debugPrint('[ScannerServer] Error resolving batch: $e');
    }

    // 3. Process according to selected scanner mode
    if (mode == 'stock') {
      // --- STOCK MODE: Directly update inventory count and write audit log ---
      final newTotalStock = medicine.totalStock + quantity;

      if (selectedBatch != null) {
        final adjustment = StockAdjustment(
          id: const Uuid().v4(),
          medicineId: medicine.id,
          medicineName: medicine.name,
          batchId: selectedBatch.id,
          batchNumber: selectedBatch.batchNumber,
          quantityChange: quantity,
          adjustmentType: 'Add',
          reason: 'Restock (Mobile Scanner)',
          createdAt: DateTime.now(),
          notes: 'Restocked via mobile scanner ($quantity units added)',
        );
        await invRepo.addStockAdjustment(adjustment, updateBatchQuantity: true);
      } else {
        // Create initial batch so SUM(batches.quantity) works
        final newBatch = Batch(
          id: const Uuid().v4(),
          medicineId: medicine.id,
          batchNumber: 'RESTOCK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          expiryDate: DateTime.now().add(const Duration(days: 365)),
          quantity: quantity,
          buyPrice: medicine.defaultCostPrice,
          sellPrice: medicine.defaultPrice,
          receivedDate: DateTime.now(),
        );
        await invRepo.addBatch(newBatch);

        final adjustment = StockAdjustment(
          id: const Uuid().v4(),
          medicineId: medicine.id,
          medicineName: medicine.name,
          batchId: newBatch.id,
          batchNumber: newBatch.batchNumber,
          quantityChange: quantity,
          adjustmentType: 'Add',
          reason: 'Restock (Mobile Scanner)',
          createdAt: DateTime.now(),
          notes: 'Restocked via mobile scanner ($quantity units added)',
        );
        await invRepo.addStockAdjustment(adjustment, updateBatchQuantity: false);
      }

      await medRepo.updateMedicine(medicine.copyWith(totalStock: newTotalStock));

      // Invalidate providers to update POS and inventory tables in real-time
      _ref.invalidate(medicinesListProvider);
      _ref.invalidate(allBatchesProvider);
      _ref.invalidate(dashboardStatsProvider);
      _ref.invalidate(stockAdjustmentsProvider);

      final notifyMsg = '📦 Restocked: ${medicine.name} (+$quantity units, Total: $newTotalStock)';
      debugPrint('[ScannerServer] $notifyMsg');

      if (mounted) {
        state = state.copyWith(lastStockRestockedMessage: notifyMsg);
      }

      sendAck({
        'status': 'success',
        'medicineName': medicine.name,
        'newStock': newTotalStock,
        'mode': 'stock',
        'quantity': quantity,
        'warning': warning,
      });
      return;
    }

    // --- SALE MODE: Add to active POS billing cart ---
    final isFullBox = !medicine.isTabletOrPack;
    cartNotifier.addItem(
      medicine,
      selectedBatch: selectedBatch,
      isFullBox: isFullBox,
      quantity: quantity,
    );

    final packSize = medicine.effectivePackSize;
    final basePrice = selectedBatch?.sellPrice ?? medicine.defaultPrice;
    final unitPrice = isFullBox ? basePrice : (basePrice / packSize);

    // Send acknowledgment back to mobile phone
    sendAck({
      'status': 'success',
      'medicineName': '${medicine.name} (${isFullBox ? "Box" : "Tablet"})',
      'price': unitPrice,
      'mode': 'sale',
      'quantity': quantity,
      'warning': warning,
    });
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }
}

final scannerServerProvider = StateNotifierProvider<ScannerServerNotifier, ScannerServerState>(
  (ref) => ScannerServerNotifier(ref),
);

// ==========================================
// 2. MOBILE PHONE WEBSOCKET CLIENT PROVIDER
// ==========================================

class ScannerClientState {
  final bool isConnected;
  final bool isConnecting;
  final bool isReconnecting;
  final String serverName;
  final List<ScanLogItem> recentLogs;
  final String? errorMessage;
  final ScannerMode selectedMode;
  final int stockQuantity;
  final ScannerTransport transportType;

  ScannerClientState({
    this.isConnected = false,
    this.isConnecting = false,
    this.isReconnecting = false,
    this.serverName = '',
    this.recentLogs = const [],
    this.errorMessage,
    this.selectedMode = ScannerMode.sale,
    this.stockQuantity = 1,
    this.transportType = ScannerTransport.wifi,
  });

  ScannerClientState copyWith({
    bool? isConnected,
    bool? isConnecting,
    bool? isReconnecting,
    String? serverName,
    List<ScanLogItem>? recentLogs,
    String? errorMessage,
    bool clearError = false,
    ScannerMode? selectedMode,
    int? stockQuantity,
    ScannerTransport? transportType,
  }) {
    return ScannerClientState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      serverName: serverName ?? this.serverName,
      recentLogs: recentLogs ?? this.recentLogs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedMode: selectedMode ?? this.selectedMode,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      transportType: transportType ?? this.transportType,
    );
  }
}

class ScannerClientNotifier extends StateNotifier<ScannerClientState> {
  final ScannerClient _client = ScannerClient();

  ScannerClientNotifier() : super(ScannerClientState()) {
    _initCallbacks();
  }

  void _initCallbacks() {
    _client.onConnectionChanged = (connected, reconnecting) {
      if (mounted) {
        state = state.copyWith(
          isConnected: connected,
          isConnecting: _client.isConnecting,
          isReconnecting: reconnecting,
          serverName: _client.serverName,
          clearError: connected,
        );
      }
    };

    _client.onLogsUpdated = (logs) {
      if (mounted) {
        state = state.copyWith(recentLogs: logs);
      }
    };

    _client.onError = (err) {
      if (mounted) {
        state = state.copyWith(
          errorMessage: err,
          isConnecting: false,
        );
      }
    };
  }

  void setMode(ScannerMode mode) {
    state = state.copyWith(selectedMode: mode);
  }

  void setStockQuantity(int qty) {
    state = state.copyWith(stockQuantity: qty.clamp(1, 9999));
  }

  void incrementStockQuantity([int amount = 1]) {
    state = state.copyWith(stockQuantity: (state.stockQuantity + amount).clamp(1, 9999));
  }

  void decrementStockQuantity([int amount = 1]) {
    state = state.copyWith(stockQuantity: (state.stockQuantity - amount).clamp(1, 9999));
  }

  void setTransport(ScannerTransport transport) {
    state = state.copyWith(transportType: transport);
  }

  /// Connect using scanned QR payload
  Future<bool> connectWithPayload(ScannerPairingPayload payload) async {
    state = state.copyWith(transportType: ScannerTransport.wifi);
    return connect(
      ip: payload.ip,
      port: payload.port,
      token: payload.token,
      deviceName: 'Mobile Scanner (${payload.name})',
    );
  }

  /// One-tap connect for USB Direct Mode (via ADB reverse tcp:8089 tcp:8089)
  Future<bool> connectUsb({String token = ''}) async {
    state = state.copyWith(transportType: ScannerTransport.usb);
    return connect(
      ip: '127.0.0.1',
      port: 8089,
      token: token.isNotEmpty ? token : 'usb',
      deviceName: 'Mobile Scanner (USB Cable)',
    );
  }

  /// Connect using manual IP entry
  Future<bool> connect({
    required String ip,
    required int port,
    required String token,
    String? deviceName,
  }) async {
    state = state.copyWith(isConnecting: true, clearError: true);
    final success = await _client.connect(
      ip: ip,
      port: port,
      token: token,
      deviceName: deviceName ?? 'Mobile Scanner',
    );
    return success;
  }

  /// Send barcode scan to POS terminal with mode and quantity
  bool sendBarcode(String barcode, {int? customQuantity}) {
    final modeStr = state.selectedMode == ScannerMode.stock ? 'stock' : 'sale';
    final qty = customQuantity ?? (state.selectedMode == ScannerMode.stock ? state.stockQuantity : 1);
    return _client.sendScan(barcode, mode: modeStr, quantity: qty);
  }

  void disconnect() {
    _client.disconnect();
    state = ScannerClientState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _client.disconnect();
    super.dispose();
  }
}

final scannerClientProvider = StateNotifierProvider<ScannerClientNotifier, ScannerClientState>(
  (ref) => ScannerClientNotifier(),
);
