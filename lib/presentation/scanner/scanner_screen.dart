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
    }
  }

  @override
  void dispose() {
    _manualBarcodeController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _tokenController.dispose();
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
        // Paired: Process medicine barcode scan
        final sent = ref.read(scannerClientProvider.notifier).sendBarcode(rawValue.trim());
        if (sent) {
          HapticFeedback.lightImpact();
          SystemSound.play(SystemSoundType.click);
          break;
        }
      }
    }
  }

  void _handleManualBarcodeSubmit() {
    final code = _manualBarcodeController.text.trim();
    if (code.isEmpty) return;

    final sent = ref.read(scannerClientProvider.notifier).sendBarcode(code);
    if (sent) {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
      _manualBarcodeController.clear();
      setState(() => _showManualEntry = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to POS terminal first')),
      );
    }
  }

  void _handleManualPairingSubmit() {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8089;
    final token = _tokenController.text.trim();

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter terminal IP address')),
      );
      return;
    }

    ref.read(scannerClientProvider.notifier).connect(
      ip: ip,
      port: port,
      token: token,
      deviceName: 'Mobile Scanner',
    );
    setState(() => _showManualPairing = false);
  }

  @override
  Widget build(BuildContext context) {
    final clientState = ref.watch(scannerClientProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Camera Viewfinder (or Desktop Simulation Console)
            if (_isCameraSupported && _scannerController != null)
              Positioned.fill(
                child: MobileScanner(
                  controller: _scannerController!,
                  onDetect: _onBarcodeDetected,
                ),
              )
            else
              Positioned.fill(
                child: _buildDesktopConsole(isDark, clientState),
              ),

            // 2. Scan Reticle Overlay (Active when camera is running)
            if (_isCameraSupported)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 280,
                      height: clientState.isConnected ? 160 : 260,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: clientState.isConnected ? AppColors.success : AppColors.primary,
                          width: 2.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Container(
                              height: 1.5,
                              color: (clientState.isConnected ? AppColors.success : AppColors.primary).withValues(alpha: 0.7),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Text(
                              clientState.isConnected ? 'Align barcode in box' : 'Scan POS pairing QR code',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
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

            // 3. Top Floating App Bar (Status & Controls)
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: _buildTopBar(context, clientState),
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

  Widget _buildTopBar(BuildContext context, ScannerClientState clientState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
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
                  ? AppColors.success
                  : (clientState.isConnecting || clientState.isReconnecting ? Colors.amber : Colors.red),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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
                Text(
                  clientState.isConnected
                      ? 'Ready to scan medicine'
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
              tooltip: 'Manual IP entry',
              onPressed: () => setState(() => _showManualPairing = !_showManualPairing),
            ),
        ],
      ),
    );
  }

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

          // Manual Pair Form (Toggleable)
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
                  const Text('Manual Terminal Pairing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            hintText: 'POS IP (e.g. 192.168.1.5)',
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
                        child: const Text('Pair', style: TextStyle(fontSize: 12)),
                      ),
                    ],
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
                  'Recent Scans',
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
              constraints: const BoxConstraints(maxHeight: 140),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: clientState.recentLogs.length,
                separatorBuilder: (_, _) => const Divider(height: 6),
                itemBuilder: (context, index) {
                  final item = clientState.recentLogs[index];
                  return Row(
                    children: [
                      Icon(
                        item.isSuccess ? Icons.check_circle_rounded : Icons.help_outline_rounded,
                        size: 16,
                        color: item.isSuccess ? AppColors.success : Colors.amber,
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
                              'Code: ${item.barcode}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (item.price != null)
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
                clientState.isConnected ? 'No scans yet. Point camera at medicine barcode.' : 'Scan POS screen QR code to connect.',
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
                      hintText: 'Enter barcode number manually...',
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

  /// Fallback display when run on Desktop (Windows) where camera hardware is not active
  Widget _buildDesktopConsole(bool isDark, ScannerClientState clientState) {
    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDarkBg : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.stay_current_portrait_rounded,
                color: AppColors.primary,
                size: 56,
              ),
              const SizedBox(height: 14),
              const Text(
                'Mobile Scanner Mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Camera scanning runs on Android & iOS mobile devices.\nOn desktop, you can test by typing or pasting barcodes below.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              // Test barcode input
              TextField(
                controller: _manualBarcodeController,
                decoration: const InputDecoration(
                  hintText: 'Enter test barcode or SKU...',
                  prefixIcon: Icon(Icons.barcode_reader, size: 20),
                ),
                onSubmitted: (_) => _handleManualBarcodeSubmit(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleManualBarcodeSubmit,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Simulate Scan Event'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
