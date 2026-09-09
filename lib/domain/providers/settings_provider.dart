import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/app_settings.dart';
import '../../data/repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider((ref) => SettingsRepository());

class SettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  final SettingsRepository _repo;

  SettingsNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    state = const AsyncValue.loading();
    try {
      final settings = await _repo.getSettings();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    // Instantly reflect theme change in UI
    state = AsyncValue.data(newSettings);
    try {
      await _repo.updateSettings(newSettings);
    } catch (e) {
      // Keep state as data even if DB write warning occurs
    }
  }

  Future<void> toggleDarkMode() async {
    final current = state.value ?? AppSettings();
    final updated = current.copyWith(isDarkMode: !current.isDarkMode);
    await updateSettings(updated);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<AppSettings>>(
  (ref) => SettingsNotifier(ref.watch(settingsRepositoryProvider)),
);
