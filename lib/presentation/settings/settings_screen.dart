import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/app_settings.dart';
import '../../domain/providers/settings_provider.dart';
import '../../domain/providers/medicine_provider.dart';
import '../../domain/providers/inventory_provider.dart';
import '../../domain/providers/sales_provider.dart';
import '../../domain/providers/report_provider.dart';
import '../../domain/providers/scanner_provider.dart';
import '../pos/widgets/scanner_pairing_dialog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/toast_helper.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../core/widgets/skeleton_loader.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _taxNumCtrl;
  late TextEditingController _lowStockCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _taxNumCtrl = TextEditingController();
    _lowStockCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _taxNumCtrl.dispose();
    _lowStockCtrl.dispose();
    super.dispose();
  }

  bool _initializedControllers = false;

  void _populateControllers(AppSettings settings) {
    if (!_initializedControllers) {
      _nameCtrl.text = settings.pharmacyName;
      _addressCtrl.text = settings.address;
      _phoneCtrl.text = settings.phone;
      _emailCtrl.text = settings.email;
      _taxNumCtrl.text = settings.taxNumber;
      _lowStockCtrl.text = '${settings.defaultLowStockThreshold}';
      _initializedControllers = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'System & Pharmacy Configuration',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Store branding, currency symbol, low stock alerts, and database backup tools',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 18),

          settingsAsync.when(
            data: (settings) {
              _populateControllers(settings);

              return Column(
                children: [
                  // Section 0: Appearance & Interface Theme
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.getBorder(context)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: settings.isDarkMode ? Colors.amber.withValues(alpha: 0.2) : AppColors.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  settings.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                  color: settings.isDarkMode ? Colors.amber : AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Interface Theme Mode',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.getTextPrimary(context),
                                      ),
                                    ),
                                    Text(
                                      settings.isDarkMode ? 'Currently using Dark Theme' : 'Currently using Light Theme',
                                      style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context)),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: settings.isDarkMode,
                                activeTrackColor: AppColors.primary,
                                onChanged: (val) {
                                  ref.read(settingsProvider.notifier).toggleDarkMode();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    if (settings.isDarkMode) {
                                      ref.read(settingsProvider.notifier).toggleDarkMode();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: !settings.isDarkMode ? AppColors.primaryLight : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: !settings.isDarkMode ? AppColors.primary : AppColors.getBorder(context),
                                        width: !settings.isDarkMode ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.light_mode_rounded, size: 18, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Light Mode',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: !settings.isDarkMode ? AppColors.primary : AppColors.getTextPrimary(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    if (!settings.isDarkMode) {
                                      ref.read(settingsProvider.notifier).toggleDarkMode();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: settings.isDarkMode ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: settings.isDarkMode ? AppColors.primary : AppColors.getBorder(context),
                                        width: settings.isDarkMode ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.dark_mode_rounded, size: 18, color: Colors.amber),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Dark Mode',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: settings.isDarkMode ? AppColors.primary : AppColors.getTextPrimary(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section: Wireless Mobile Barcode Scanner (Offline Gateway)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.getBorder(context)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: ref.watch(scannerServerProvider).hasPairedDevice
                                      ? AppColors.successLight
                                      : AppColors.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  ref.watch(scannerServerProvider).hasPairedDevice
                                      ? Icons.phonelink_ring_rounded
                                      : Icons.qr_code_scanner_rounded,
                                  color: ref.watch(scannerServerProvider).hasPairedDevice
                                      ? AppColors.success
                                      : AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wireless Mobile Barcode Scanner',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.getTextPrimary(context),
                                      ),
                                    ),
                                    Text(
                                      'Use any mobile phone as a wireless camera scanner over local Wi-Fi or Hotspot (100% offline).',
                                      style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(context)),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => ScannerPairingDialog.show(context),
                                icon: const Icon(Icons.qr_code_rounded, size: 16),
                                label: Text(
                                  ref.watch(scannerServerProvider).hasPairedDevice
                                      ? 'Manage Scanner'
                                      : 'Pair Mobile Scanner',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ref.watch(scannerServerProvider).hasPairedDevice
                                      ? AppColors.success
                                      : AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: ref.watch(scannerServerProvider).hasPairedDevice
                                  ? AppColors.successLight.withValues(alpha: 0.3)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: ref.watch(scannerServerProvider).hasPairedDevice
                                    ? AppColors.success.withValues(alpha: 0.3)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ref.watch(scannerServerProvider).hasPairedDevice
                                        ? AppColors.success
                                        : (ref.watch(scannerServerProvider).isRunning ? Colors.amber : Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ref.watch(scannerServerProvider).hasPairedDevice
                                        ? 'Connected: ${ref.watch(scannerServerProvider).pairedDevice!.name} (${ref.watch(scannerServerProvider).pairedDevice!.ipAddress})'
                                        : (ref.watch(scannerServerProvider).isRunning
                                            ? 'Server listening on port ${ref.watch(scannerServerProvider).port} • Waiting for phone to connect'
                                            : 'Scanner server is idle • Click Pair to activate'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: ref.watch(scannerServerProvider).hasPairedDevice
                                          ? const Color(0xFF15803D)
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (ref.watch(scannerServerProvider).hasPairedDevice)
                                  TextButton(
                                    onPressed: () => ref.read(scannerServerProvider.notifier).disconnectDevice(),
                                    child: const Text('Disconnect', style: TextStyle(color: Colors.red, fontSize: 11)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section 1: Pharmacy Business Profile
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.store_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Pharmacy Business Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Pharmacy Name *',
                                    prefixIcon: Icon(
                                      Icons.business_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Contact Phone *',
                                    prefixIcon: Icon(
                                      Icons.phone_outlined,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _taxNumCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Tax / License Registration #',
                                    prefixIcon: Icon(
                                      Icons.badge_outlined,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          TextField(
                            controller: _addressCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Physical Store Address',
                              prefixIcon: Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section 2: Regional & Currency Settings
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.infoLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.language_rounded,
                                  color: AppColors.info,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Regional & Currency Settings',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Currency Symbol',
                                    prefixIcon: Icon(
                                      Icons.attach_money_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  initialValue: settings.currencySymbol,
                                  items: const [
                                    DropdownMenuItem(
                                      value: '\$',
                                      child: Text('\$ (US Dollar)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Rs',
                                      child: Text('Rs (Rupees)'),
                                    ),
                                    DropdownMenuItem(
                                      value: '€',
                                      child: Text('€ (Euro)'),
                                    ),
                                    DropdownMenuItem(
                                      value: '£',
                                      child: Text('£ (Pound)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'AED',
                                      child: Text('AED (Dirham)'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      ref
                                          .read(settingsProvider.notifier)
                                          .updateSettings(
                                            settings.copyWith(
                                              currencySymbol: val,
                                            ),
                                          );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _lowStockCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Low Stock Alert Threshold',
                                    prefixIcon: Icon(
                                      Icons.warning_amber_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Save Settings Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final updated = settings.copyWith(
                          pharmacyName: _nameCtrl.text.trim(),
                          address: _addressCtrl.text.trim(),
                          phone: _phoneCtrl.text.trim(),
                          email: _emailCtrl.text.trim(),
                          taxNumber: _taxNumCtrl.text.trim(),
                          defaultTaxRate: 0.0,
                          defaultLowStockThreshold:
                              int.tryParse(_lowStockCtrl.text) ?? 15,
                        );

                        await ref
                            .read(settingsProvider.notifier)
                            .updateSettings(updated);
                        if (context.mounted) {
                          ToastHelper.showSuccess(
                            context,
                            'Pharmacy settings saved successfully!',
                          );
                        }
                      },
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text(
                        'Save Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: const Color(0xFFF1F5F9)),
                    child: const Divider(height: 1),
                  ),
                  const SizedBox(height: 20),

                  // Section 4: Data Management & Backup Restore
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.backup_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Database Backup & Restore',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Offline SQLite database management and JSON backup tools',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _exportBackup(context),
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Export DB Backup (JSON)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _importBackup(context, ref),
                                  icon: const Icon(
                                    Icons.upload_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Restore DB Backup',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final confirmed = await ConfirmationDialog.show(
                                      context,
                                      title: 'Reset & Clear All Data',
                                      message:
                                          'WARNING: This will permanently wipe all medicines, inventory batches, sales invoices, and customer records from SQLite. Proceed?',
                                      confirmLabel: 'Clear All Data',
                                    );
                                    if (confirmed == true) {
                                      await DatabaseHelper.instance
                                          .clearAllData();
                                      ref.invalidate(medicinesListProvider);
                                      ref.invalidate(allBatchesProvider);
                                      ref.invalidate(salesListProvider);
                                      ref.invalidate(dashboardStatsProvider);
                                      if (context.mounted) {
                                        ToastHelper.showSuccess(
                                          context,
                                          'All database data cleared',
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Clear All Database Data',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.danger,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SkeletonLoader(height: 300),
            error: (err, _) =>
                Center(child: Text('Error loading settings: $err')),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final dataStr = await DatabaseHelper.instance.exportDatabaseJson();
      if (context.mounted) {
        ToastHelper.showSuccess(
          context,
          'SQLite DB Backup generated (${dataStr.length} bytes)',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, 'Backup error: $e');
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result != null && result.files.isNotEmpty && context.mounted) {
        ToastHelper.showInfo(context, 'Database backup file loaded');
      }
    } catch (e) {
      if (context.mounted) {
        ToastHelper.showError(context, 'Import error: $e');
      }
    }
  }
}
