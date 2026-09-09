import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../data/models/paired_device.dart';

/// Payload structure embedded inside the POS Terminal's pairing QR code.
class ScannerPairingPayload {
  final String type; // Always 'ahmad_pos_scanner'
  final String name;
  final String ip;
  final int port;
  final String token;

  ScannerPairingPayload({
    this.type = 'ahmad_pos_scanner',
    required this.name,
    required this.ip,
    required this.port,
    required this.token,
  });

  String toJsonString() {
    return jsonEncode({
      'type': type,
      'name': name,
      'ip': ip,
      'port': port,
      'token': token,
    });
  }

  static ScannerPairingPayload? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is Map<String, dynamic> && decoded['type'] == 'ahmad_pos_scanner') {
        return ScannerPairingPayload(
          name: decoded['name'] as String? ?? 'Ahmad Pharmacy Terminal',
          ip: decoded['ip'] as String? ?? '',
          port: (decoded['port'] as num?)?.toInt() ?? 8089,
          token: decoded['token'] as String? ?? '',
        );
      }
    } catch (_) {}
    return null;
  }
}

/// Offline WebSocket Server hosted directly on the POS Terminal.
///
/// Offline Pairing Flow:
/// 1. POS Terminal starts [ScannerServer] on port 8089 (or fallback port).
/// 2. [getLocalIps] discovers local IPv4 addresses (LAN Wi-Fi or Windows Mobile Hotspot).
/// 3. POS renders a QR code encoding [ScannerPairingPayload] on screen.
/// 4. Phone scans the QR code or manually inputs IP:port + pairing token.
/// 5. Single-device pairing policy ensures only 1 scanner attaches at a time.
class ScannerServer {
  HttpServer? _server;
  WebSocket? _activeClient;
  PairedDevice? _pairedDevice;
  String _pairingToken = '';
  int _port = 8089;
  List<String> _localIps = [];

  // Callbacks
  Function(PairedDevice? device)? onDeviceChanged;
  Function(
    String barcode,
    String mode,
    int quantity,
    Function(Map<String, dynamic> response) sendAck,
  )? onScanReceived;

  bool get isRunning => _server != null;
  PairedDevice? get pairedDevice => _pairedDevice;
  String get pairingToken => _pairingToken;
  int get port => _port;
  List<String> get localIps => _localIps;

  /// Start server on local network
  Future<bool> start({int preferredPort = 8089}) async {
    if (isRunning) return true;

    _port = preferredPort;
    _pairingToken = _generateRandomToken();
    _localIps = await getLocalIps();

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _server!.listen(_handleHttpRequest);
      debugPrint('[ScannerServer] Running on port $_port with IPs: $_localIps');
      return true;
    } catch (e) {
      debugPrint('[ScannerServer] Failed to bind port $_port: $e');
      // Try fallback port
      try {
        _port = preferredPort + 1;
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
        _server!.listen(_handleHttpRequest);
        debugPrint('[ScannerServer] Running on fallback port $_port with IPs: $_localIps');
        return true;
      } catch (err) {
        debugPrint('[ScannerServer] Fatal server start error: $err');
        return false;
      }
    }
  }

  /// Stop server and disconnect any active client
  Future<void> stop() async {
    disconnectCurrentDevice();
    await _server?.close(force: true);
    _server = null;
    _localIps = [];
    _pairedDevice = null;
    onDeviceChanged?.call(null);
  }

  /// Disconnect current paired scanner device
  void disconnectCurrentDevice() {
    if (_activeClient != null) {
      try {
        _activeClient!.add(jsonEncode({
          'type': 'disconnect_ack',
          'message': 'Disconnected by POS terminal',
        }));
        _activeClient!.close(1000, 'Terminal disconnected');
      } catch (_) {}
      _activeClient = null;
    }
    _pairedDevice = null;
    onDeviceChanged?.call(null);
  }

  void _handleHttpRequest(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then((WebSocket socket) {
        _handleNewSocket(socket, request.connectionInfo?.remoteAddress.address ?? 'Unknown');
      }).catchError((err) {
        debugPrint('[ScannerServer] WebSocket upgrade error: $err');
      });
    } else {
      // Basic healthcheck response for browser/curl inspection
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'status': 'active',
          'service': 'Ahmad Pharmacy Offline POS Scanner Gateway',
          'paired': _pairedDevice != null,
        }))
        ..close();
    }
  }

  void _handleNewSocket(WebSocket socket, String remoteIp) {
    socket.listen(
      (data) {
        _processClientMessage(socket, remoteIp, data);
      },
      onDone: () {
        if (_activeClient == socket) {
          debugPrint('[ScannerServer] Client disconnected: ${_pairedDevice?.name}');
          _activeClient = null;
          _pairedDevice = null;
          onDeviceChanged?.call(null);
        }
      },
      onError: (err) {
        debugPrint('[ScannerServer] Socket error: $err');
        if (_activeClient == socket) {
          _activeClient = null;
          _pairedDevice = null;
          onDeviceChanged?.call(null);
        }
      },
      cancelOnError: true,
    );
  }

  void _processClientMessage(WebSocket socket, String remoteIp, dynamic rawData) {
    try {
      final message = jsonDecode(rawData.toString()) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'pair':
          final token = message['token'] as String? ?? '';
          final deviceName = message['deviceName'] as String? ?? 'Mobile Scanner';

          // Validate token
          if (token != _pairingToken) {
            socket.add(jsonEncode({
              'type': 'error',
              'message': 'Invalid pairing token. Please scan the latest QR code on screen.',
            }));
            socket.close(4001, 'Invalid token');
            return;
          }

          // Single-device policy: reject if another device is currently connected
          if (_activeClient != null && _activeClient != socket) {
            socket.add(jsonEncode({
              'type': 'error',
              'message': 'Another scanner (${_pairedDevice?.name}) is already paired to this terminal.',
            }));
            socket.close(4002, 'Terminal busy');
            return;
          }

          _activeClient = socket;
          _pairedDevice = PairedDevice(
            id: 'dev_${DateTime.now().millisecondsSinceEpoch}',
            name: deviceName,
            ipAddress: remoteIp,
            connectedAt: DateTime.now(),
            lastPingAt: DateTime.now(),
            status: PairedDeviceStatus.connected,
          );

          socket.add(jsonEncode({
            'type': 'pair_ack',
            'status': 'paired',
            'terminalName': 'Ahmad Pharmacy Terminal',
          }));

          onDeviceChanged?.call(_pairedDevice);
          break;

        case 'scan':
          if (_activeClient != socket) {
            socket.add(jsonEncode({
              'type': 'error',
              'message': 'Device not paired.',
            }));
            return;
          }

          final barcode = message['barcode'] as String? ?? '';
          final mode = (message['mode'] as String?)?.toLowerCase() == 'stock' ? 'stock' : 'sale';
          final quantity = (message['quantity'] as num?)?.toInt() ?? 1;
          if (barcode.trim().isEmpty) return;

          _pairedDevice = _pairedDevice?.copyWith(lastPingAt: DateTime.now());

          // Dispatch scan to POS terminal pipeline
          if (onScanReceived != null) {
            onScanReceived!(barcode.trim(), mode, quantity, (ackData) {
              try {
                socket.add(jsonEncode({
                  'type': 'scan_ack',
                  'barcode': barcode.trim(),
                  'mode': mode,
                  'quantity': quantity,
                  ...ackData,
                }));
              } catch (_) {}
            });
          }
          break;

        case 'ping':
          _pairedDevice = _pairedDevice?.copyWith(lastPingAt: DateTime.now());
          socket.add(jsonEncode({'type': 'pong', 'timestamp': DateTime.now().millisecondsSinceEpoch}));
          break;

        case 'disconnect':
          if (_activeClient == socket) {
            disconnectCurrentDevice();
          }
          break;

        default:
          debugPrint('[ScannerServer] Unknown message: $type');
      }
    } catch (e) {
      debugPrint('[ScannerServer] Error processing message: $e');
    }
  }

  /// Discover all IPv4 local network adapter addresses (Wi-Fi, Ethernet, Hotspot)
  static Future<List<String>> getLocalIps() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            ips.add(addr.address);
          }
        }
      }
    } catch (e) {
      debugPrint('[ScannerServer] Error discovering network interfaces: $e');
    }

    if (ips.isEmpty) {
      ips.add('127.0.0.1');
    }
    return ips;
  }

  static String _generateRandomToken() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString(); // 6 digit pairing PIN
  }
}

/// Item displayed in the phone's on-screen scan history log
class ScanLogItem {
  final String barcode;
  final String title;
  final String mode; // 'sale' or 'stock'
  final int quantity;
  final double? price;
  final int? newStock;
  final bool isSuccess;
  final String? warning;
  final DateTime timestamp;

  ScanLogItem({
    required this.barcode,
    required this.title,
    this.mode = 'sale',
    this.quantity = 1,
    this.price,
    this.newStock,
    required this.isSuccess,
    this.warning,
    required this.timestamp,
  });
}

/// Offline WebSocket Client running on the Mobile Phone in "Scanner Mode".
class ScannerClient {
  WebSocket? _socket;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isReconnecting = false;
  String _serverName = '';
  String _lastIp = '';
  int _lastPort = 8089;
  String _lastToken = '';
  String _deviceName = 'Mobile Scanner';
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;

  // Debounce to prevent duplicate rapid scans
  String _lastScannedBarcode = '';
  int _lastScanTimeMs = 0;
  static const int debounceMs = 650;

  // Recent scans feed (last 5)
  final List<ScanLogItem> _recentLogs = [];

  Function(bool isConnected, bool isReconnecting)? onConnectionChanged;
  Function(List<ScanLogItem> logs)? onLogsUpdated;
  Function(String error)? onError;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isReconnecting => _isReconnecting;
  String get serverName => _serverName;
  List<ScanLogItem> get recentLogs => List.unmodifiable(_recentLogs);

  Future<bool> connect({
    required String ip,
    required int port,
    required String token,
    String? deviceName,
  }) async {
    _lastIp = ip;
    _lastPort = port;
    _lastToken = token;
    if (deviceName != null) _deviceName = deviceName;

    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _isConnecting = true;
    onConnectionChanged?.call(false, false);

    try {
      final uri = Uri.parse('ws://$ip:$port');
      _socket = await WebSocket.connect(uri.toString()).timeout(const Duration(seconds: 4));

      // Send handshake
      _socket!.add(jsonEncode({
        'type': 'pair',
        'token': _lastToken,
        'deviceName': _deviceName,
      }));

      _socket!.listen(
        _handleServerMessage,
        onDone: _onSocketClosed,
        onError: (err) {
          debugPrint('[ScannerClient] Socket error: $err');
          _onSocketClosed();
        },
        cancelOnError: true,
      );

      _isConnecting = false;
      _reconnectAttempts = 0;
      _startHeartbeat();
      return true;
    } catch (e) {
      _isConnecting = false;
      debugPrint('[ScannerClient] Failed to connect: $e');
      onError?.call('Could not connect to POS terminal at $ip:$port. Ensure both devices are on the same Wi-Fi or Hotspot.');
      onConnectionChanged?.call(false, false);
      return false;
    }
  }

  void _handleServerMessage(dynamic rawData) {
    try {
      final message = jsonDecode(rawData.toString()) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'pair_ack':
          _isConnected = true;
          _isReconnecting = false;
          _serverName = message['terminalName'] as String? ?? 'Ahmad Pharmacy Terminal';
          onConnectionChanged?.call(true, false);
          break;

        case 'scan_ack':
          final barcode = message['barcode'] as String? ?? '';
          final status = message['status'] as String? ?? '';
          final mode = message['mode'] as String? ?? 'sale';
          final quantity = (message['quantity'] as num?)?.toInt() ?? 1;
          final medName = message['medicineName'] as String? ?? (status == 'success' ? 'Medicine Processed' : 'Unrecognized Barcode');
          final price = (message['price'] as num?)?.toDouble();
          final newStock = (message['newStock'] as num?)?.toInt();
          final warning = message['warning'] as String?;

          final logItem = ScanLogItem(
            barcode: barcode,
            title: medName,
            mode: mode,
            quantity: quantity,
            price: price,
            newStock: newStock,
            isSuccess: status == 'success',
            warning: warning,
            timestamp: DateTime.now(),
          );

          _recentLogs.insert(0, logItem);
          if (_recentLogs.length > 5) {
            _recentLogs.removeLast();
          }
          onLogsUpdated?.call(List.unmodifiable(_recentLogs));
          break;

        case 'error':
          final msg = message['message'] as String? ?? 'Connection error';
          onError?.call(msg);
          break;

        case 'pong':
          // Heartbeat healthy
          break;

        case 'disconnect_ack':
          disconnect();
          break;
      }
    } catch (e) {
      debugPrint('[ScannerClient] Message parsing error: $e');
    }
  }

  /// Send barcode scan event with mode and quantity, with debounce check
  bool sendScan(String barcode, {String mode = 'sale', int quantity = 1}) {
    if (!_isConnected || _socket == null) return false;

    final code = barcode.trim();
    if (code.isEmpty) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (code == _lastScannedBarcode && (now - _lastScanTimeMs) < debounceMs) {
      // Debounced duplicate scan
      return false;
    }

    _lastScannedBarcode = code;
    _lastScanTimeMs = now;

    try {
      _socket!.add(jsonEncode({
        'type': 'scan',
        'barcode': code,
        'mode': mode,
        'quantity': quantity,
        'timestamp': now,
      }));
      return true;
    } catch (e) {
      debugPrint('[ScannerClient] Error sending scan: $e');
      return false;
    }
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_isConnected && _socket != null) {
        try {
          _socket!.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _onSocketClosed() {
    _socket = null;
    _pingTimer?.cancel();

    if (_isConnected) {
      _isConnected = false;
      _isReconnecting = true;
      onConnectionChanged?.call(false, true);
      _scheduleReconnect();
    } else {
      _isReconnecting = false;
      onConnectionChanged?.call(false, false);
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    final delaySec = min(pow(2, _reconnectAttempts).toInt(), 8);
    debugPrint('[ScannerClient] Reconnecting in ${delaySec}s (attempt $_reconnectAttempts)...');

    _reconnectTimer = Timer(Duration(seconds: delaySec), () async {
      if (!_isConnected && _lastIp.isNotEmpty) {
        final success = await connect(
          ip: _lastIp,
          port: _lastPort,
          token: _lastToken,
          deviceName: _deviceName,
        );
        if (!success && _isReconnecting) {
          _scheduleReconnect();
        }
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _isReconnecting = false;
    _isConnecting = false;

    if (_socket != null) {
      try {
        _socket!.add(jsonEncode({'type': 'disconnect'}));
        _socket!.close(1000, 'User disconnected');
      } catch (_) {}
      _socket = null;
    }

    _isConnected = false;
    _recentLogs.clear();
    onConnectionChanged?.call(false, false);
    onLogsUpdated?.call([]);
  }
}
