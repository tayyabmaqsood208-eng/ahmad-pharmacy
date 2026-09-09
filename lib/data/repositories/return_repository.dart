import '../models/return.dart';
import '../../core/database/database_helper.dart';

class ReturnRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String> generateReturnNo() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final prefix = 'RET-${now.year}${now.month.toString().padLeft(2, '0')}';

    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM returns WHERE return_no LIKE '$prefix%'"
    );
    final count = (result.first['count'] as num).toInt() + 1;
    return '$prefix-${count.toString().padLeft(3, '0')}';
  }

  Future<void> createReturn(PharmacyReturn returnRecord) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Insert Return record
      await txn.insert('returns', returnRecord.toMap());

      // 2. Insert Return Items & Restock Inventory
      for (final item in returnRecord.items) {
        await txn.insert('return_items', item.toMap());

        // 3. Restock inventory if restockToggle is true
        if (returnRecord.restockToggle) {
          if (item.batchId != null && item.batchId!.isNotEmpty) {
            await txn.rawUpdate(
              'UPDATE batches SET quantity = quantity + ? WHERE id = ?',
              [item.quantity, item.batchId],
            );
          } else {
            // Find most recent batch for this medicine to restock
            final batches = await txn.query(
              'batches',
              where: 'medicine_id = ?',
              whereArgs: [item.medicineId],
              orderBy: 'received_date DESC',
              limit: 1,
            );
            if (batches.isNotEmpty) {
              final bId = batches.first['id'] as String;
              await txn.rawUpdate(
                'UPDATE batches SET quantity = quantity + ? WHERE id = ?',
                [item.quantity, bId],
              );
            }
          }
        }
      }

      // 4. Update parent Sale status (Refunded if fully returned, Partially Refunded if partial)
      final sItems = await txn.query('sale_items', where: 'sale_id = ?', whereArgs: [returnRecord.saleId]);
      int totalPurchased = 0;
      for (final iMap in sItems) {
        totalPurchased += (iMap['quantity'] as num).toInt();
      }

      final retItemsMap = await txn.rawQuery(
        'SELECT SUM(ri.quantity) as total_returned FROM return_items ri JOIN returns r ON ri.return_id = r.id WHERE r.sale_id = ?',
        [returnRecord.saleId],
      );
      int totalReturned = 0;
      if (retItemsMap.isNotEmpty && retItemsMap.first['total_returned'] != null) {
        totalReturned = (retItemsMap.first['total_returned'] as num).toInt();
      }

      final String updatedStatus = (totalReturned >= totalPurchased && totalPurchased > 0) ? 'Refunded' : 'Partially Refunded';

      await txn.update(
        'sales',
        {'status': updatedStatus},
        where: 'id = ?',
        whereArgs: [returnRecord.saleId],
      );

      // 5. Deduct returned amount from Customer credit balance
      final saleMaps = await txn.query('sales', where: 'id = ?', whereArgs: [returnRecord.saleId]);
      String? targetCustomerId;

      if (saleMaps.isNotEmpty) {
        targetCustomerId = saleMaps.first['customer_id'] as String?;
      }

      if (targetCustomerId == null || targetCustomerId.isEmpty) {
        final custName = returnRecord.customerName.trim().toLowerCase();
        if (custName.isNotEmpty && custName != 'walk-in customer') {
          final custs = await txn.query('customers');
          for (final cMap in custs) {
            final cName = (cMap['name'] as String).trim().toLowerCase();
            if (cName == custName || cName.startsWith(custName) || custName.startsWith(cName)) {
              targetCustomerId = cMap['id'] as String;
              await txn.update(
                'returns',
                {'customer_id': targetCustomerId},
                where: 'id = ?',
                whereArgs: [returnRecord.id],
              );
              break;
            }
          }
        }
      }

      if (targetCustomerId != null && targetCustomerId.isNotEmpty) {
        await txn.rawUpdate(
          'UPDATE customers SET credit_balance = MAX(0.0, ROUND(credit_balance - ?, 2)) WHERE id = ?',
          [returnRecord.totalRefund, targetCustomerId],
        );
      }
    });
  }

  Future<List<PharmacyReturn>> getReturns({String? query}) async {
    final db = await _dbHelper.database;

    String whereClause = 'WHERE 1=1';
    List<dynamic> whereArgs = [];

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      whereClause += ' AND (LOWER(return_no) LIKE ? OR LOWER(invoice_no) LIKE ? OR LOWER(customer_name) LIKE ?)';
      whereArgs.addAll([q, q, q]);
    }

    final maps = await db.rawQuery(
      'SELECT * FROM returns $whereClause ORDER BY return_date DESC',
      whereArgs,
    );

    List<PharmacyReturn> returns = [];
    for (final map in maps) {
      final returnId = map['id'] as String;
      final itemMaps = await db.query('return_items', where: 'return_id = ?', whereArgs: [returnId]);
      final items = itemMaps.map((i) => ReturnItem.fromMap(i)).toList();
      returns.add(PharmacyReturn.fromMap(map, items: items));
    }

    return returns;
  }
}
