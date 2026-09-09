import 'package:sqflite/sqflite.dart';

class DemoSeeder {
  /// Detects and purges pre-seeded demo data from SQLite database.
  static Future<void> purgeDemoData(Database db) async {
    final countResult = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM medicines WHERE id LIKE 'med-%' OR id = 'med-001'",
      ),
    );
    if (countResult != null && countResult > 0) {
      await clearAllData(db);
    }
  }

  /// Clears all stored data from database tables.
  static Future<void> clearAllData(Database db) async {
    await db.transaction((txn) async {
      await txn.delete('sale_items');
      await txn.delete('sales');
      await txn.delete('purchase_items');
      await txn.delete('purchases');
      await txn.delete('return_items');
      await txn.delete('returns');
      await txn.delete('stock_adjustments');
      await txn.delete('batches');
      await txn.delete('medicines');
      await txn.delete('customers');
    });
  }

  /// Kept for interface compatibility; does not inject demo data.
  static Future<void> seedDatabase(Database db) async {
    // Demo auto-seeding disabled.
  }
}

