import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/scanner_network_service.dart';
import '../../data/models/paired_device.dart';
import '../../data/models/batch.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/repositories/medicine_repository.dart';
import 'pos_cart_provider.dart';

// Repositories
final medicineRepoProvider = Provider((ref) => MedicineRepository());
final inventoryRepoProvider = Provider((ref) => InventoryRepository());

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

  ScannerServerState({
    this.isRunning = false,
    this.port = 8089,
    this.localIps = const [],
    this.selectedIp = '',
    this.pairingToken = '',
    this.pairedDevice,
    this.lastUnknownBarcode,
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
  }) {
    return ScannerServerState(
      isRunning: isRunning ?? this.isRunning,
      port: port ?? this.port,
      localIps: localIps ?? this.localIps,
      selectedIp: selectedIp ?? this.selectedIp,
      pairingToken: pairingToken ?? this.pairingToken,
      pairedDevice: clearPairedDevice ? null : (pairedDevice ?? this.pairedDevice),
      lastUnknownBarcode: clearUnknownBarcode ? null : (lastUnknownBarcode ?? this.lastUnknownBarcode),
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

    _server.onScanReceived = (barcode, sendAck) async {
      await _handleIncomingScan(barcode, sendAck);
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

  /// Incoming scan processor: resolves barcode -> FEFO batch -> active POS cart
  Future<void> _handleIncomingScan(String barcode, Function(Map<String, dynamic>) sendAck) async {
    final medRepo = _ref.read(medicineRepoProvider);
    final invRepo = _ref.read(inventoryRepoProvider);
    final cartNotifier = _ref.read(posCartProvider.notifier);

    // 1. Lookup medicine in offline local SQLite database
    final medicine = await medRepo.getMedicineByBarcode(barcode);

    if (medicine == null) {
      // Unrecognized barcode
      debugPrint('[ScannerServer] Unknown barcode scanned: $barcode');
      if (mounted) {
        state = state.copyWith(lastUnknownBarcode: barcode);
      }
      sendAck({
        'status': 'unknown',
        'message': 'Unrecognized Barcode',
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
      } else {
        warning = 'Warning: No batch stock recorded';
      }
    } catch (e) {
      debugPrint('[ScannerServer] Error resolving batch: $e');
    }

    // 3. Add to POS cart (defaults to single tablet if medicine is a pack/tablet)
    final isFullBox = !medicine.isTabletOrPack;
    cartNotifier.addItem(
      medicine,
      selectedBatch: selectedBatch,
      isFullBox: isFullBox,
      quantity: 1,
    );

    final packSize = medicine.effectivePackSize;
    final basePrice = selectedBatch?.sellPrice ?? medicine.defaultPrice;
    final unitPrice = isFullBox ? basePrice : (basePrice / packSize);

    // 4. Send acknowledgment back to mobile phone for on-screen log
    sendAck({
      'status': 'success',
      'medicineName': '${medicine.name} (${isFullBox ? "Box" : "Tablet"})',
      'price': unitPrice,
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

  ScannerClientState({
    this.isConnected = false,
    this.isConnecting = false,
    this.isReconnecting = false,
    this.serverName = '',
    this.recentLogs = const [],
    this.errorMessage,
  });

  ScannerClientState copyWith({
    bool? isConnected,
    bool? isConnecting,
    bool? isReconnecting,
    String? serverName,
    List<ScanLogItem>? recentLogs,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ScannerClientState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      serverName: serverName ?? this.serverName,
      recentLogs: recentLogs ?? this.recentLogs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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

  /// Connect using scanned QR payload
  Future<bool> connectWithPayload(ScannerPairingPayload payload) async {
    return connect(
      ip: payload.ip,
      port: payload.port,
      token: payload.token,
      deviceName: 'Mobile Scanner (${payload.name})',
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

  /// Send barcode scan to POS terminal
  bool sendBarcode(String barcode) {
    return _client.sendScan(barcode);
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
