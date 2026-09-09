import '../models/batch.dart';
import '../models/stock_adjustment.dart';
import '../../core/database/database_helper.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Batch>> getBatchesForMedicine(String medicineId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'batches',
      where: 'medicine_id = ? AND quantity > 0',
      whereArgs: [medicineId],
      orderBy: 'expiry_date ASC',
    );
    return maps.map((map) => Batch.fromMap(map)).toList();
  }

  Future<List<Batch>> getAllBatches({String? query, String? filterStatus}) async {
    final db = await _dbHelper.database;
    final maps = await db.query('batches', orderBy: 'expiry_date ASC');
    List<Batch> batches = maps.map((map) => Batch.fromMap(map)).toList();

    if (filterStatus == 'Expiring Soon') {
      batches = batches.where((b) => b.isExpiringSoon && !b.isExpired).toList();
    } else if (filterStatus == 'Expired') {
      batches = batches.where((b) => b.isExpired).toList();
    } else if (filterStatus == 'Low Stock') {
      batches = batches.where((b) => b.quantity <= 10).toList();
    }

    return batches;
  }

  Future<List<Batch>> getExpiringBatches({int withinDays = 60}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final target = now.add(Duration(days: withinDays));

    final maps = await db.query(
      'batches',
      where: 'expiry_date <= ? AND quantity > 0',
      whereArgs: [target.toIso8601String()],
      orderBy: 'expiry_date ASC',
    );

    return maps.map((map) => Batch.fromMap(map)).toList();
  }

  Future<void> addBatch(Batch batch) async {
    final db = await _dbHelper.database;
    await db.insert('batches', batch.toMap());
  }

  Future<void> updateBatch(Batch batch) async {
    final db = await _dbHelper.database;
    await db.update(
      'batches',
      batch.toMap(),
      where: 'id = ?',
      whereArgs: [batch.id],
    );
  }

  Future<void> addStockAdjustment(StockAdjustment adjustment, {bool updateBatchQuantity = true}) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('stock_adjustments', adjustment.toMap());

      if (updateBatchQuantity && adjustment.batchId != null) {
        final batchMaps = await txn.query(
          'batches',
          where: 'id = ?',
          whereArgs: [adjustment.batchId],
        );
        if (batchMaps.isNotEmpty) {
          final currentQty = (batchMaps.first['quantity'] as num).toInt();
          final newQty = (currentQty + adjustment.quantityChange).clamp(0, 999999);
          await txn.update(
            'batches',
            {'quantity': newQty},
            where: 'id = ?',
            whereArgs: [adjustment.batchId],
          );
        }
      }
    });
  }

  Future<List<StockAdjustment>> getStockAdjustments() async {
    final db = await _dbHelper.database;
    final maps = await db.query('stock_adjustments', orderBy: 'created_at DESC');
    return maps.map((map) => StockAdjustment.fromMap(map)).toList();
  }

  Future<void> updateAllBatchPricesForMedicine(String medicineId, double buyPrice, double sellPrice) async {
    final db = await _dbHelper.database;
    await db.update(
      'batches',
      {
        'buy_price': buyPrice,
        'sell_price': sellPrice,
      },
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
    );
  }
}
