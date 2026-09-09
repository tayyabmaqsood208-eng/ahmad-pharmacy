import '../models/medicine.dart';
import '../../core/database/database_helper.dart';

class MedicineRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Medicine>> getMedicines({
    String? query,
    String? category,
    bool? lowStockOnly,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = 'WHERE 1=1';
    List<dynamic> whereArgs = [];

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      whereClause += " AND (LOWER(m.name) LIKE ? OR LOWER(m.generic_name) LIKE ? OR LOWER(m.sku) LIKE ? OR LOWER(COALESCE(m.barcode, '')) LIKE ? OR LOWER(COALESCE(m.salt_composition, '')) LIKE ?)";
      whereArgs.addAll([q, q, q, q, q]);
    }

    if (category != null && category != 'All' && category.isNotEmpty) {
      whereClause += ' AND m.category = ?';
      whereArgs.add(category);
    }

    final String rawQuery = '''
      SELECT m.*, COALESCE(SUM(b.quantity), 0) as total_stock
      FROM medicines m
      LEFT JOIN batches b ON m.id = b.medicine_id
      $whereClause
      GROUP BY m.id
      ORDER BY m.name ASC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(rawQuery, whereArgs);

    List<Medicine> medicines = maps.map((map) {
      final totalStock = (map['total_stock'] as num).toInt();
      return Medicine.fromMap(map, totalStock: totalStock);
    }).toList();

    if (lowStockOnly == true) {
      medicines = medicines.where((m) => m.isLowStock).toList();
    }

    return medicines;
  }

  Future<Medicine?> getMedicineById(String id) async {
    final db = await _dbHelper.database;
    final String rawQuery = '''
      SELECT m.*, COALESCE(SUM(b.quantity), 0) as total_stock
      FROM medicines m
      LEFT JOIN batches b ON m.id = b.medicine_id
      WHERE m.id = ?
      GROUP BY m.id
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(rawQuery, [id]);
    if (maps.isNotEmpty) {
      final totalStock = (maps.first['total_stock'] as num).toInt();
      return Medicine.fromMap(maps.first, totalStock: totalStock);
    }
    return null;
  }

  Future<Medicine?> getMedicineByBarcode(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return null;

    final db = await _dbHelper.database;
    final String rawQuery = '''
      SELECT m.*, COALESCE(SUM(b.quantity), 0) as total_stock
      FROM medicines m
      LEFT JOIN batches b ON m.id = b.medicine_id
      WHERE LOWER(m.barcode) = ? OR LOWER(m.sku) = ?
      GROUP BY m.id
      LIMIT 1
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      rawQuery,
      [cleanCode.toLowerCase(), cleanCode.toLowerCase()],
    );

    if (maps.isNotEmpty) {
      final totalStock = (maps.first['total_stock'] as num).toInt();
      return Medicine.fromMap(maps.first, totalStock: totalStock);
    }
    return null;
  }

  Future<List<String>> getCategories() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT DISTINCT category FROM medicines ORDER BY category ASC');
    final categories = result.map((row) => row['category'] as String).where((c) => c.isNotEmpty).toList();
    return ['All', ...categories];
  }

  Future<void> addMedicine(Medicine medicine) async {
    final db = await _dbHelper.database;
    await db.insert('medicines', medicine.toMap());
  }

  Future<void> updateMedicine(Medicine medicine) async {
    final db = await _dbHelper.database;
    await db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<void> deleteMedicine(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('batches', where: 'medicine_id = ?', whereArgs: [id]);
      await txn.delete('medicines', where: 'id = ?', whereArgs: [id]);
    });
  }
}
