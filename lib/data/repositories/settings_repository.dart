import '../models/app_settings.dart';
import '../../core/database/database_helper.dart';

class SettingsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<AppSettings> getSettings() async {
    final db = await _dbHelper.database;
    final maps = await db.query('settings', where: 'id = 1');
    if (maps.isNotEmpty) {
      return AppSettings.fromMap(maps.first);
    }
    return AppSettings();
  }

  Future<void> updateSettings(AppSettings settings) async {
    final db = await _dbHelper.database;
    await db.update(
      'settings',
      settings.toMap(),
      where: 'id = 1',
    );
  }
}
