import 'package:uuid/uuid.dart';
import '../models/purchase.dart';
import '../../core/database/database_helper.dart';

class PurchaseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String> generatePurchaseInvoiceNo() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final prefix = 'PUR-${now.year}${now.month.toString().padLeft(2, '0')}';

    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM purchases WHERE invoice_no LIKE '$prefix%'"
    );
    final count = (result.first['count'] as num).toInt() + 1;
    return '$prefix-${count.toString().padLeft(3, '0')}';
  }

  Future<void> createPurchase(Purchase purchase) async {
    final db = await _dbHelper.database;
    const uuid = Uuid();

    await db.transaction((txn) async {
      // 1. Insert Purchase
      await txn.insert('purchases', purchase.toMap());

      // 2. Insert Purchase Items & create/update medicine Batches
      for (final item in purchase.items) {
        await txn.insert('purchase_items', item.toMap());

        // Check if batch number already exists for this medicine
        final existingBatches = await txn.query(
          'batches',
          where: 'medicine_id = ? AND batch_number = ?',
          whereArgs: [item.medicineId, item.batchNumber],
        );

        if (existingBatches.isNotEmpty) {
          // Update existing batch quantity and cost
          final currentQty = (existingBatches.first['quantity'] as num).toInt();
          await txn.update(
            'batches',
            {
              'quantity': currentQty + item.quantity,
              'buy_price': item.buyPrice,
              'sell_price': item.sellPrice,
              'expiry_date': item.expiryDate.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [existingBatches.first['id']],
          );
        } else {
          // Create new batch entry
          await txn.insert('batches', {
            'id': 'bat-${uuid.v4().substring(0, 8)}',
            'medicine_id': item.medicineId,
            'batch_number': item.batchNumber,
            'expiry_date': item.expiryDate.toIso8601String(),
            'quantity': item.quantity,
            'buy_price': item.buyPrice,
            'sell_price': item.sellPrice,
            'received_date': purchase.purchaseDate.toIso8601String(),
          });
        }
      }
    });
  }

  Future<List<Purchase>> getPurchases({String? query, String? status}) async {
    final db = await _dbHelper.database;

    String whereClause = 'WHERE 1=1';
    List<dynamic> whereArgs = [];

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      whereClause += ' AND (LOWER(invoice_no) LIKE ? OR LOWER(vendor_name) LIKE ?)';
      whereArgs.addAll([q, q]);
    }

    if (status != null && status != 'All' && status.isNotEmpty) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    final maps = await db.rawQuery(
      'SELECT * FROM purchases $whereClause ORDER BY purchase_date DESC',
      whereArgs,
    );

    List<Purchase> purchases = [];
    for (final map in maps) {
      final purchaseId = map['id'] as String;
      final itemMaps = await db.query('purchase_items', where: 'purchase_id = ?', whereArgs: [purchaseId]);
      final items = itemMaps.map((i) => PurchaseItem.fromMap(i)).toList();
      purchases.add(Purchase.fromMap(map, items: items));
    }

    return purchases;
  }
}
