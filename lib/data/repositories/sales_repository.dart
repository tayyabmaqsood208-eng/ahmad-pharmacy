import '../models/sale.dart';
import '../../core/database/database_helper.dart';

class SalesRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String> generateInvoiceNo() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final prefix = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sales WHERE invoice_no LIKE '$prefix%'"
    );
    final count = (result.first['count'] as num).toInt() + 1;
    return '$prefix-${count.toString().padLeft(3, '0')}';
  }

  Future<void> createSale(Sale sale) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Insert Sale record
      await txn.insert('sales', sale.toMap());

      // 2. Insert Sale Items and deduct stock from batches
      for (final item in sale.items) {
        await txn.insert('sale_items', item.toMap());

        // Calculate units to deduct from inventory batches
        final medMaps = await txn.query('medicines', columns: ['pack_size'], where: 'id = ?', whereArgs: [item.medicineId]);
        final packSize = (medMaps.isNotEmpty ? (medMaps.first['pack_size'] as num?)?.toInt() : 1) ?? 1;
        final isBox = item.medicineName.contains('(Box)') || item.medicineName.contains('(Pack)');
        final int deductUnits = isBox ? (item.quantity * (packSize > 0 ? packSize : 1)) : item.quantity;

        if (item.batchId != null) {
          // Deduct from specific batch
          await txn.rawUpdate(
            'UPDATE batches SET quantity = MAX(0, quantity - ?) WHERE id = ?',
            [deductUnits, item.batchId],
          );
        } else {
          // Auto deduct FEFO (First Expired First Out)
          final batches = await txn.query(
            'batches',
            where: 'medicine_id = ? AND quantity > 0',
            whereArgs: [item.medicineId],
            orderBy: 'expiry_date ASC',
          );

          int remainingToDeduct = deductUnits;
          for (final batchMap in batches) {
            if (remainingToDeduct <= 0) break;
            final batchId = batchMap['id'] as String;
            final currentQty = (batchMap['quantity'] as num).toInt();

            if (currentQty >= remainingToDeduct) {
              await txn.rawUpdate(
                'UPDATE batches SET quantity = quantity - ? WHERE id = ?',
                [remainingToDeduct, batchId],
              );
              remainingToDeduct = 0;
            } else {
              await txn.rawUpdate(
                'UPDATE batches SET quantity = 0 WHERE id = ?',
                [batchId],
              );
              remainingToDeduct -= currentQty;
            }
          }
        }
      }

      // 3. Update Customer total purchases and credit balance if paid on Store Credit
      String? targetCustomerId = sale.customerId;

      if (targetCustomerId == null || targetCustomerId.isEmpty) {
        if (sale.customerName.isNotEmpty && sale.customerName.trim() != 'Walk-in Customer') {
          final sName = sale.customerName.trim().toLowerCase();
          final custs = await txn.query('customers');
          for (final cMap in custs) {
            final cName = (cMap['name'] as String).trim().toLowerCase();
            if (cName == sName || cName.startsWith(sName) || sName.startsWith(cName)) {
              targetCustomerId = cMap['id'] as String;
              await txn.update(
                'sales',
                {'customer_id': targetCustomerId},
                where: 'id = ?',
                whereArgs: [sale.id],
              );
              break;
            }
          }
        }
      }

      if (targetCustomerId != null && targetCustomerId.isNotEmpty) {
        final custMaps = await txn.query('customers', where: 'id = ?', whereArgs: [targetCustomerId]);
        if (custMaps.isNotEmpty) {
          final currentPurchases = (custMaps.first['total_purchases'] as num).toDouble();
          final currentCredit = (custMaps.first['credit_balance'] as num).toDouble();

          double newCredit = currentCredit;
          if (sale.paymentMethod == 'Store Credit' || sale.paymentMethod == 'Credit') {
            newCredit += sale.totalAmount;
          }

          await txn.update(
            'customers',
            {
              'total_purchases': currentPurchases + sale.totalAmount,
              'credit_balance': newCredit,
            },
            where: 'id = ?',
            whereArgs: [targetCustomerId],
          );
        }
      }
    });
  }

  Future<List<Sale>> getSales({
    String? query,
    String? status,
    String? paymentMethod,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;

    try {
      // Auto sync sales refund status (Refunded vs Partially Refunded)
      final returnsMap = await db.rawQuery(
        'SELECT r.sale_id, SUM(ri.quantity) as total_returned FROM return_items ri JOIN returns r ON ri.return_id = r.id GROUP BY r.sale_id'
      );
      Map<String, int> returnedQtyBySale = {};
      for (final r in returnsMap) {
        final sId = r['sale_id'] as String;
        final qty = (r['total_returned'] as num).toInt();
        returnedQtyBySale[sId] = qty;
      }

      final allSalesMap = await db.query('sales');
      for (final sMap in allSalesMap) {
        final sId = sMap['id'] as String;
        final currentStatus = sMap['status'] as String? ?? 'Completed';
        if (currentStatus == 'Voided') continue;

        final sItems = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [sId]);
        int totalPurchased = 0;
        for (final itemMap in sItems) {
          totalPurchased += (itemMap['quantity'] as num).toInt();
        }

        final returnedCount = returnedQtyBySale[sId] ?? 0;
        String expectedStatus = currentStatus;

        if (returnedCount >= totalPurchased && totalPurchased > 0) {
          expectedStatus = 'Refunded';
        } else if (returnedCount > 0) {
          expectedStatus = 'Partially Refunded';
        } else if (currentStatus == 'Refunded' || currentStatus == 'Partially Refunded') {
          expectedStatus = 'Completed';
        }

        if (expectedStatus != currentStatus) {
          await db.update('sales', {'status': expectedStatus}, where: 'id = ?', whereArgs: [sId]);
        }
      }
    } catch (_) {}

    String whereClause = 'WHERE 1=1';
    List<dynamic> whereArgs = [];

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      whereClause += ' AND (LOWER(invoice_no) LIKE ? OR LOWER(customer_name) LIKE ?)';
      whereArgs.addAll([q, q]);
    }

    if (status != null && status != 'All' && status.isNotEmpty) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    if (paymentMethod != null && paymentMethod != 'All' && paymentMethod.isNotEmpty) {
      whereClause += ' AND payment_method = ?';
      whereArgs.add(paymentMethod);
    }

    if (startDate != null) {
      whereClause += ' AND created_at >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClause += ' AND created_at <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final maps = await db.rawQuery(
      'SELECT * FROM sales $whereClause ORDER BY created_at DESC',
      whereArgs,
    );

    List<Sale> sales = [];
    for (final map in maps) {
      final saleId = map['id'] as String;
      final itemMaps = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      final items = itemMaps.map((i) => SaleItem.fromMap(i)).toList();
      sales.add(Sale.fromMap(map, items: items));
    }

    return sales;
  }

  Future<Sale?> getSaleById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('sales', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final itemMaps = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [id]);
      final items = itemMaps.map((i) => SaleItem.fromMap(i)).toList();
      return Sale.fromMap(maps.first, items: items);
    }
    return null;
  }

  Future<void> voidSale(String saleId, String reason) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Get Sale & Sale Items
      final saleMaps = await txn.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (saleMaps.isEmpty) return;

      final sale = Sale.fromMap(saleMaps.first);
      if (sale.status == 'Voided') return; // Already voided

      final itemMaps = await txn.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      final items = itemMaps.map((i) => SaleItem.fromMap(i)).toList();

      // 2. Mark Sale as Voided
      await txn.update(
        'sales',
        {'status': 'Voided', 'notes': 'Voided: $reason'},
        where: 'id = ?',
        whereArgs: [saleId],
      );

      // 3. Restore stock to batches
      for (final item in items) {
        final medMaps = await txn.query('medicines', columns: ['pack_size'], where: 'id = ?', whereArgs: [item.medicineId]);
        final packSize = (medMaps.isNotEmpty ? (medMaps.first['pack_size'] as num?)?.toInt() : 1) ?? 1;
        final isBox = item.medicineName.contains('(Box)') || item.medicineName.contains('(Pack)');
        final int restoreUnits = isBox ? (item.quantity * (packSize > 0 ? packSize : 1)) : item.quantity;

        if (item.batchId != null) {
          await txn.rawUpdate(
            'UPDATE batches SET quantity = quantity + ? WHERE id = ?',
            [restoreUnits, item.batchId],
          );
        }
      }

      // 4. Adjust Customer Credit balance if voided
      String? targetCustomerId = sale.customerId;

      if (targetCustomerId == null || targetCustomerId.isEmpty) {
        if (sale.customerName.isNotEmpty && sale.customerName.trim() != 'Walk-in Customer') {
          final sName = sale.customerName.trim().toLowerCase();
          final custs = await txn.query('customers');
          for (final cMap in custs) {
            final cName = (cMap['name'] as String).trim().toLowerCase();
            if (cName == sName || cName.startsWith(sName) || sName.startsWith(cName)) {
              targetCustomerId = cMap['id'] as String;
              break;
            }
          }
        }
      }

      if (targetCustomerId != null && targetCustomerId.isNotEmpty) {
        if (sale.paymentMethod == 'Store Credit' || sale.paymentMethod == 'Credit') {
          await txn.rawUpdate(
            'UPDATE customers SET credit_balance = MAX(0, credit_balance - ?) WHERE id = ?',
            [sale.totalAmount, targetCustomerId],
          );
        }
      }
    });
  }
}
