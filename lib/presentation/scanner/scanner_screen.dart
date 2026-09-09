import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/network/scanner_network_service.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/scanner_provider.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final TextEditingController _manualBarcodeController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '8089');
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _customQtyController = TextEditingController(text: '10');

  MobileScannerController? _scannerController;
  bool _isTorchOn = false;
  bool _showManualEntry = false;
  bool _showManualPairing = false;

  bool get _isCameraSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    if (_isCameraSupported) {
      _scannerController = MobileScannerController(
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.qrCode,
        ],
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    } else {
      // Running on Desktop (Windows) or Web without camera:
      // Auto-initialize POS server and auto-pair desktop simulator
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoConnectDesktopSimulator();
      });
    }
  }

  Future<void> _autoConnectDesktopSimulator() async {
    final serverNotifier = ref.read(scannerServerProvider.notifier);
    var serverState = ref.read(scannerServerProvider);
    if (!serverState.isRunning) {
      await serverNotifier.startServer();
      serverState = ref.read(scannerServerProvider);
    }
    if (mounted) {
      _tokenController.text = serverState.pairingToken;
      _ipController.text = '127.0.0.1';
    }
    final client = ref.read(scannerClientProvider);
    if (!client.isConnected && !client.isConnecting) {
      await ref.read(scannerClientProvider.notifier).connect(
        ip: '127.0.0.1',
        port: serverState.port,
        token: serverState.pairingToken,
        deviceName: 'Desktop Scanner Simulator',
      );
    }
  }

  Future<void> _restartCamera() async {
    try {
      await _scannerController?.dispose();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _scannerController = MobileScannerController(
          formats: const [
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
            BarcodeFormat.code128,
            BarcodeFormat.code39,
            BarcodeFormat.qrCode,
          ],
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
          torchEnabled: false,
        );
      });
    }
  }

  @override
  void dispose() {
    _manualBarcodeController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    _customQtyController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final clientState = ref.read(scannerClientProvider);
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.trim().isEmpty) continue;

      if (!clientState.isConnected) {
        // Not paired yet: Check if scanned code is a POS pairing QR code
        final payload = ScannerPairingPayload.tryParse(rawValue);
        if (payload != null) {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.click);
          ref.read(scannerClientProvider.notifier).connectWithPayload(payload);
          break;
        }
      } else {
        // Paired: Process medicine barcode scan in selected mode
        final sent = ref.read(scannerClientProvider.notifier).sendBarcode(rawValue.trim());
        if (sent) {
          HapticFeedback.lightImpact();
          SystemSound.play(SystemSoundType.click);
          break;
        }
      }
    }
  }

  Future<void> _handleManualBarcodeSubmit() async {
    final code = _manualBarcodeController.text.trim();
    if (code.isEmpty) return;

    var clientState = ref.read(scannerClientProvider);
    if (!clientState.isConnected && !_isCameraSupported) {
      await _autoConnectDesktopSimulator();
      clientState = ref.read(scannerClientProvider);
    }

    final sent = ref.read(scannerClientProvider.notifier).sendBarcode(code);
    if (sent) {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
      _manualBarcodeController.clear();
      setState(() => _showManualEntry = false);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please connect to POS terminal first')),
        );
      }
    }
  }

  void _handleManualPairingSubmit() {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8089;
    var token = _tokenController.text.trim();

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter terminal IP address')),
      );
      return;
    }

    if (token.isEmpty && (ip == '127.0.0.1' || ip == 'localhost')) {
      final serverToken = ref.read(scannerServerProvider).pairingToken;
      if (serverToken.isNotEmpty) {
        token = serverToken;
      } else {
        token = 'usb';
      }
    }

    ref.read(scannerClientProvider.notifier).connect(
      ip: ip,
      port: port,
      token: token,
      deviceName: 'Mobile Scanner',
    );
    setState(() => _showManualPairing = false);
  }

  void _handleUsbConnect() {
    var token = _tokenController.text.trim();
    if (token.isEmpty) {
      final serverToken = ref.read(scannerServerProvider).pairingToken;
      if (serverToken.isNotEmpty) {
        token = serverToken;
      } else {
        token = 'usb';
      }
    }
    ref.read(scannerClientProvider.notifier).connectUsb(token: token);
    setState(() => _showManualPairing = false);
  }

  @override
  Widget build(BuildContext context) {
    final clientState = ref.watch(scannerClientProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isCameraSupported || _scannerController == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.bodyDarkBg : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: _buildDesktopConsole(context, isDark, clientState),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Camera Viewfinder
            Positioned.fill(
              child: MobileScanner(
                controller: _scannerController!,
                onDetect: _onBarcodeDetected,
                errorBuilder: (context, error, child) {
                  return Container(
                    color: Colors.black,
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_off_rounded, color: Colors.amber, size: 52),
                          const SizedBox(height: 12),
                          const Text(
                            'Camera Access Required',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.errorCode == MobileScannerErrorCode.permissionDenied
                                ? 'Camera permission was denied. Please allow camera access in your phone Settings to scan medicine barcodes.'
                                : 'Unable to start camera: ${error.errorDetails?.message ?? error.errorCode.name}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _restartCamera,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Allow / Retry Camera'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 2. Scan Reticle Overlay (Active when camera is running)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 280,
                    height: clientState.isConnected ? 160 : 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: clientState.isConnected
                            ? (clientState.selectedMode == ScannerMode.stock ? Colors.amber : AppColors.success)
                            : AppColors.primary,
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            height: 1.5,
                            color: (clientState.isConnected
                                    ? (clientState.selectedMode == ScannerMode.stock ? Colors.amber : AppColors.success)
                                    : AppColors.primary)
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Text(
                            !clientState.isConnected
                                ? 'Scan POS pairing QR code'
                                : (clientState.selectedMode == ScannerMode.stock
                                    ? 'Stock Mode: Scan to add +${clientState.stockQuantity} units'
                                    : 'Sale Mode: Scan to add to bill'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Top Floating App Bar & Mode Switcher
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTopBar(context, clientState),
                  const SizedBox(height: 8),
                  _buildModeSelector(clientState),
                  if (clientState.selectedMode == ScannerMode.stock && clientState.isConnected) ...[
                    const SizedBox(height: 8),
                    _buildStockQuantityBar(clientState),
                  ],
                ],
              ),
            ),

            // 4. Bottom Panel: Recent Scans History Feed & Manual Input
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomPanel(context, clientState, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // --- TOP FLOATING APP BAR ---
  Widget _buildTopBar(BuildContext context, ScannerClientState clientState) {
    final isUsb = clientState.transportType == ScannerTransport.usb;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Connection Status Dot & Title
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: clientState.isConnected
                  ? (isUsb ? Colors.lightBlueAccent : AppColors.success)
                  : (clientState.isConnecting || clientState.isReconnecting ? Colors.amber : Colors.red),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        clientState.isConnected
                            ? clientState.serverName
                            : (clientState.isReconnecting
                                ? 'Reconnecting...'
                                : (clientState.isConnecting ? 'Connecting...' : 'Not Connected')),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (clientState.isConnected) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (isUsb ? Colors.blue : Colors.green).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (isUsb ? Colors.blueAccent : Colors.greenAccent).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          isUsb ? 'USB' : 'Wi-Fi',
                          style: TextStyle(
                            color: isUsb ? Colors.lightBlueAccent : Colors.lightGreenAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  clientState.isConnected
                      ? (clientState.selectedMode == ScannerMode.stock
                          ? 'Stock Mode: Receiving inventory'
                          : 'Sale Mode: Billing active cart')
                      : 'Scan POS QR code to attach',
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ),

          // Flashlight Toggle (if camera supported)
          if (_isCameraSupported && _scannerController != null)
            IconButton(
              icon: Icon(
                _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _isTorchOn ? Colors.amber : Colors.white70,
                size: 20,
              ),
              onPressed: () {
                _scannerController?.toggleTorch();
                setState(() => _isTorchOn = !_isTorchOn);
              },
            ),

          // Disconnect or Manual Pair Button
          if (clientState.isConnected)
            TextButton(
              onPressed: () => ref.read(scannerClientProvider.notifier).disconnect(),
              child: const Text('Unpair', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            )
          else
            IconButton(
              icon: const Icon(Icons.settings_ethernet_rounded, color: Colors.white70, size: 20),
              tooltip: 'Manual IP or USB entry',
              onPressed: () => setState(() => _showManualPairing = !_showManualPairing),
            ),
        ],
      ),
    );
  }

  // --- DUAL MODE SELECTOR: SALE MODE vs STOCK MODE ---
  Widget _buildModeSelector(ScannerClientState clientState) {
    final isSale = clientState.selectedMode == ScannerMode.sale;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Sale Mode Button
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(scannerClientProvider.notifier).setMode(ScannerMode.sale);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSale ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSale
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_rounded,
                      size: 15,
                      color: isSale ? Colors.white : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sale Mode',
                      style: TextStyle(
                        color: isSale ? Colors.white : Colors.white70,
                        fontWeight: isSale ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Stock Mode Button
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(scannerClientProvider.notifier).setMode(ScannerMode.stock);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !isSale ? const Color(0xFFD97706) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: !isSale
                      ? [
                          BoxShadow(
                            color: const Color(0xFFD97706).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_rounded,
                      size: 15,
                      color: !isSale ? Colors.white : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Stock Mode',
                      style: TextStyle(
                        color: !isSale ? Colors.white : Colors.white70,
                        fontWeight: !isSale ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STOCK MODE BATCH QUANTITY SELECTOR BAR ---
  Widget _buildStockQuantityBar(ScannerClientState clientState) {
    final qty = clientState.stockQuantity;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.add_shopping_cart_rounded, color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Restock Batch Size:',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              // Stepper controls
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref.read(scannerClientProvider.notifier).decrementStockQuantity(1);
                    },
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showCustomQuantityDialog(context, qty),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+$qty units',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref.read(scannerClientProvider.notifier).incrementStockQuantity(1);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Quick Preset Chips (+1, +5, +10, +25, +50, +100)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [1, 5, 10, 25, 50, 100].map((preset) {
                final isSelected = qty == preset;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(scannerClientProvider.notifier).setStockQuantity(preset);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF59E0B) : Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+$preset',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomQuantityDialog(BuildContext context, int currentQty) {
    _customQtyController.text = currentQty.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Restock Quantity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _customQtyController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Quantity to add...',
            suffixText: 'units',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(_customQtyController.text.trim()) ?? currentQty;
              ref.read(scannerClientProvider.notifier).setStockQuantity(parsed);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            child: const Text('Set Quantity'),
          ),
        ],
      ),
    );
  }

  // --- BOTTOM PANEL: RECENT SCANS LOG & MANUAL ENTRY ---
  Widget _buildBottomPanel(BuildContext context, ScannerClientState clientState, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle pill
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          // Error banner if any
          if (clientState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      clientState.errorMessage!,
                      style: const TextStyle(fontSize: 11, color: AppColors.danger),
                      maxLines: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 12, color: AppColors.danger),
                    onPressed: () => ref.read(scannerClientProvider.notifier).clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Manual Pair Form (Toggleable: Wi-Fi IP or USB Loopback)
          if (_showManualPairing && !clientState.isConnected) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bodyDarkBg : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pair to POS Terminal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _showManualPairing = false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Option 1: Wi-Fi LAN IP input
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            hintText: 'Terminal IP (192.168.x.x)',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _tokenController,
                          decoration: const InputDecoration(
                            hintText: 'PIN',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: _handleManualPairingSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Connect', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Option 2: Direct USB Cable (ADB Reverse)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.usb_rounded, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'USB Cable Direct Mode (No Wi-Fi needed)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue),
                              ),
                              Text(
                                'Plug cable & run: adb reverse tcp:8089 tcp:8089 on PC',
                                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _handleUsbConnect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          child: const Text('USB Connect', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Recent Scans Feed (Last 3 to 5 items)
          if (clientState.recentLogs.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Scans Feed',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${clientState.recentLogs.length} items logged',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: clientState.recentLogs.length,
                separatorBuilder: (_, _) => const Divider(height: 6),
                itemBuilder: (context, index) {
                  final item = clientState.recentLogs[index];
                  final isStock = item.mode == 'stock';

                  return Row(
                    children: [
                      Icon(
                        item.isSuccess ? Icons.check_circle_rounded : Icons.help_outline_rounded,
                        size: 16,
                        color: item.isSuccess
                            ? (isStock ? const Color(0xFFD97706) : AppColors.success)
                            : Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      // Mode badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isStock ? const Color(0xFFFEF3C7) : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isStock ? const Color(0xFFF59E0B) : AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          isStock ? 'STOCK' : 'SALE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isStock ? const Color(0xFFD97706) : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Code: ${item.barcode}${isStock ? " • Qty: +${item.quantity}" : ""}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (isStock && item.newStock != null)
                        Text(
                          'Total: ${item.newStock}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD97706)),
                        )
                      else if (!isStock && item.price != null)
                        Text(
                          'Rs ${item.price!.toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                clientState.isConnected
                    ? (clientState.selectedMode == ScannerMode.stock
                        ? 'Stock Mode active. Scan medicine barcode to restock +${clientState.stockQuantity} units.'
                        : 'Sale Mode active. Scan medicine barcode to add to bill.')
                    : 'Scan POS screen QR code to connect.',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],

          // Manual Barcode Input Fallback
          if (_showManualEntry) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualBarcodeController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: clientState.selectedMode == ScannerMode.stock
                          ? 'Enter barcode to restock (+${clientState.stockQuantity})...'
                          : 'Enter barcode to add to bill...',
                      isDense: true,
                      prefixIcon: const Icon(Icons.keyboard_alt_outlined, size: 16),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded, size: 18, color: AppColors.primary),
                        onPressed: _handleManualBarcodeSubmit,
                      ),
                    ),
                    onSubmitted: (_) => _handleManualBarcodeSubmit(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _showManualEntry = false),
                ),
              ],
            ),
          ] else ...[
            TextButton.icon(
              onPressed: () => setState(() => _showManualEntry = true),
              icon: const Icon(Icons.keyboard_rounded, size: 16),
              label: const Text('Type barcode manually', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  /// Clean, scrollable display when run on Desktop (Windows) where camera hardware is not active
  Widget _buildDesktopConsole(BuildContext context, bool isDark, ScannerClientState clientState) {
    final isStock = clientState.selectedMode == ScannerMode.stock;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(context, clientState),
              const SizedBox(height: 10),
              _buildModeSelector(clientState),
              if (isStock && clientState.isConnected) ...[
                const SizedBox(height: 10),
                _buildStockQuantityBar(clientState),
              ],
              const SizedBox(height: 16),

              // Simulation Barcode Terminal Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDarkBg : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isStock ? Icons.inventory_2_rounded : Icons.stay_current_portrait_rounded,
                      color: isStock ? const Color(0xFFD97706) : AppColors.primary,
                      size: 44,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isStock ? 'Desktop Scanner (Stock Restock Mode)' : 'Desktop Scanner (POS Sale Mode)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isStock
                          ? 'Simulate stock receiving scan: adds quantity directly to inventory DB.'
                          : 'Simulate sale scan: resolves medicine and adds to active billing cart.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    // Barcode input
                    TextField(
                      controller: _manualBarcodeController,
                      decoration: InputDecoration(
                        hintText: isStock
                            ? 'Enter barcode to restock (+${clientState.stockQuantity} units)...'
                            : 'Enter test barcode or SKU...',
                        prefixIcon: const Icon(Icons.barcode_reader, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (_) => _handleManualBarcodeSubmit(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleManualBarcodeSubmit,
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          isStock
                              ? 'Simulate Restock Scan (+${clientState.stockQuantity} Units)'
                              : 'Simulate Sale Cart Scan',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isStock ? const Color(0xFFD97706) : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Recent Scans Feed & Connection Tools
              _buildBottomPanel(context, clientState, isDark),
            ],
          ),
        ),
      ),
    );
  }
}
