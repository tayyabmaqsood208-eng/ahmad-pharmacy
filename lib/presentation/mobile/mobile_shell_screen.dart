import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/providers/pos_cart_provider.dart';
import '../../domain/providers/scanner_provider.dart';
import '../../domain/providers/settings_provider.dart';
import '../scanner/scanner_screen.dart';
import 'mobile_stock_screen.dart';
import 'mobile_bill_screen.dart';

class MobileShellScreen extends ConsumerStatefulWidget {
  const MobileShellScreen({super.key});

  @override
  ConsumerState<MobileShellScreen> createState() => _MobileShellScreenState();
}

class _MobileShellScreenState extends ConsumerState<MobileShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(posCartProvider);
    final clientState = ref.watch(scannerClientProvider);
    final settingsVal = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartCount = cartState.totalItemCount;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        elevation: 0.5,
        backgroundColor: isDark ? AppColors.cardDarkBg : Colors.white,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    settingsVal.value?.pharmacyName ?? 'Ahmad Pharmacy',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    clientState.isConnected
                        ? '● Paired to ${clientState.serverName.isNotEmpty ? clientState.serverName : "POS"}'
                        : '● Offline Standalone',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: clientState.isConnected ? AppColors.success : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Connection Mode Pill
          InkWell(
            onTap: () => _showPairingSheet(context, clientState),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: clientState.isConnected ? AppColors.successLight : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: clientState.isConnected ? AppColors.success.withValues(alpha: 0.4) : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    clientState.isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    size: 14,
                    color: clientState.isConnected ? AppColors.success : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    clientState.isConnected ? 'Paired' : 'Pair POS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: clientState.isConnected ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Dark Mode Toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
              color: isDark ? Colors.amber : AppColors.textSecondary,
            ),
            onPressed: () {
              ref.read(settingsProvider.notifier).toggleDarkMode();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      // Body: 3 dedicated mobile pages in IndexedStack
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          ScannerScreen(),
          MobileStockScreen(),
          MobileBillScreen(),
        ],
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkBg : Colors.white,
          border: Border(top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border, width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          height: 62,
          backgroundColor: Colors.transparent,
          indicatorColor: _currentIndex == 1
              ? const Color(0xFFFEF3C7)
              : AppColors.primaryLight,
          onDestinationSelected: (idx) {
            setState(() => _currentIndex = idx);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_rounded),
              selectedIcon: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
              label: 'QR Scanner',
            ),
            const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded, color: Color(0xFFD97706)),
              label: 'Stock',
            ),
            NavigationDestination(
              icon: Badge(
                label: Text('$cartCount'),
                isLabelVisible: cartCount > 0,
                child: const Icon(Icons.receipt_long_outlined),
              ),
              selectedIcon: Badge(
                label: Text('$cartCount'),
                isLabelVisible: cartCount > 0,
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
              ),
              label: 'Create Bill',
            ),
          ],
        ),
      ),
    );
  }

  void _showPairingSheet(BuildContext context, ScannerClientState clientState) {
    final ipCtrl = TextEditingController(text: '192.168.');
    final pinCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Terminal Connection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Connect phone to your Windows counter PC over same Wi-Fi or USB cable.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),

            if (clientState.isConnected) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Connected to: ${clientState.serverName.isNotEmpty ? clientState.serverName : "POS Counter"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(scannerClientProvider.notifier).disconnect();
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      child: const Text('Disconnect', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Wi-Fi Connection Form
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: ipCtrl,
                      decoration: const InputDecoration(
                        labelText: 'PC IP Address',
                        hintText: '192.168.x.x',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: pinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        hintText: '4-digits',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final ip = ipCtrl.text.trim();
                      final pin = pinCtrl.text.trim();
                      if (ip.isNotEmpty) {
                        ref.read(scannerClientProvider.notifier).connect(
                              ip: ip,
                              port: 8089,
                              token: pin,
                              deviceName: 'Mobile Scanner',
                            );
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    child: const Text('Pair'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // USB Direct Cable Mode
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.usb_rounded, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('USB Direct Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                          Text('Connects via 127.0.0.1:8089 (ADB reverse)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(scannerClientProvider.notifier).connectUsb();
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      child: const Text('Connect USB', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
