import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/providers/scanner_provider.dart';

class ScannerPairingDialog extends ConsumerStatefulWidget {
  const ScannerPairingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ScannerPairingDialog(),
    );
  }

  @override
  ConsumerState<ScannerPairingDialog> createState() => _ScannerPairingDialogState();
}

class _ScannerPairingDialogState extends ConsumerState<ScannerPairingDialog> {
  @override
  void initState() {
    super.initState();
    // Auto-start server if not already running when pairing dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final serverState = ref.read(scannerServerProvider);
      if (!serverState.isRunning) {
        ref.read(scannerServerProvider.notifier).startServer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(scannerServerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConnected = serverState.hasPairedDevice;
    final pairedDevice = serverState.pairedDevice;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.cardDarkBg : Colors.white,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isConnected ? AppColors.successLight : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isConnected ? Icons.phonelink_ring_rounded : Icons.qr_code_scanner_rounded,
                    color: isConnected ? AppColors.success : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wireless Mobile Scanner',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isConnected
                            ? 'Scanner is actively paired & ready to scan'
                            : 'Scan QR with phone to pair over local Wi-Fi / Hotspot',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  splashRadius: 20,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Main Body: Connected State vs QR Pairing State
            if (isConnected && pairedDevice != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.successLight.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 52,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      pairedDevice.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IP: ${pairedDevice.ipAddress} • Connected',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Point your phone camera at medicine barcodes to automatically add them to the POS invoice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(scannerServerProvider.notifier).disconnectDevice();
                      },
                      icon: const Icon(Icons.link_off_rounded, size: 16),
                      label: const Text('Disconnect Scanner'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // QR Code View for Pairing
              if (!serverState.isRunning) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Starting local scanner service...'),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: serverState.pairingQrData,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0F172A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Network IP & Token Pills
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.bodyDarkBg : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'IP: ${serverState.selectedIp}:${serverState.port}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.bodyDarkBg : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.key_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'PIN: ${serverState.pairingToken}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // IP Interface Selector (if terminal has multiple network adapters)
                if (serverState.localIps.length > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Network Adapter: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      DropdownButton<String>(
                        value: serverState.selectedIp,
                        isDense: true,
                        underline: const SizedBox(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        items: serverState.localIps.map((ip) {
                          return DropdownMenuItem(value: ip, child: Text(ip));
                        }).toList(),
                        onChanged: (newIp) {
                          if (newIp != null) {
                            ref.read(scannerServerProvider.notifier).setSelectedIp(newIp);
                          }
                        },
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // Offline instructions notice
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Open Scanner Mode on mobile app and scan this code. Both devices must be on the same Wi-Fi or Windows Mobile Hotspot.',
                          style: TextStyle(fontSize: 11, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 20),

            // Footer actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
