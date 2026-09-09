import '../../core/database/database_helper.dart';
import '../models/dashboard_stats.dart';

class ReportRepository {
  final DatabaseHelper _dbHelper;

  ReportRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<DashboardStats> getDashboardStats() async {
    final db = await _dbHelper.database;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    final todaySalesRes = await db.rawQuery('''
      SELECT SUM(total_amount) as total, COUNT(*) as count 
      FROM sales 
      WHERE created_at LIKE '$todayStr%' AND status != 'Voided'
    ''');
    final todaySales = (todaySalesRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final todayOrders = (todaySalesRes.first['count'] as int?) ?? 0;

    final revRes = await db.rawQuery('''
      SELECT SUM(total_amount) as total FROM sales WHERE status != 'Voided'
    ''');
    final totalRevenue = (revRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final lowStockRes = await db.rawQuery('''
      SELECT COUNT(*) as count FROM medicines m
      WHERE (SELECT COALESCE(SUM(quantity), 0) FROM batches b WHERE b.medicine_id = m.id AND b.expiry_date >= date('now')) < m.min_stock
    ''');
    final lowStockCount = (lowStockRes.first['count'] as int?) ?? 0;

    final expiringRes = await db.rawQuery('''
      SELECT COUNT(*) as count FROM batches 
      WHERE expiry_date <= date('now', '+60 days') AND quantity > 0
    ''');
    final expiringCount = (expiringRes.first['count'] as int?) ?? 0;

    return DashboardStats(
      todaySales: todaySales,
      todayOrders: todayOrders,
      totalRevenue: totalRevenue,
      lowStockCount: lowStockCount,
      expiringCount: expiringCount,
    );
  }

  Future<Map<String, double>> getStockValuation() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT 
        SUM(quantity * buy_price) as total_cost,
        SUM(quantity * sell_price) as total_retail
      FROM batches
      WHERE quantity > 0
    ''');

    final totalCost = (result.first['total_cost'] as num?)?.toDouble() ?? 0.0;
    final totalRetail = (result.first['total_retail'] as num?)?.toDouble() ?? 0.0;

    return {
      'totalCost': totalCost,
      'totalRetail': totalRetail,
      'potentialProfit': totalRetail - totalCost,
    };
  }

  Future<List<Map<String, dynamic>>> getTopSellingMedicines({int limit = 5}) async {
    final db = await _dbHelper.database;

    final results = await db.rawQuery('''
      SELECT medicine_id, medicine_name, SUM(quantity) as total_qty, SUM(total) as total_revenue
      FROM sale_items
      GROUP BY medicine_id, medicine_name
      ORDER BY total_qty DESC
      LIMIT ?
    ''', [limit]);

    return results.map((row) {
      return {
        'id': row['medicine_id'] as String,
        'name': row['medicine_name'] as String,
        'quantity': (row['total_qty'] as num).toInt(),
        'revenue': (row['total_revenue'] as num).toDouble(),
      };
    }).toList();
  }

  Future<Map<String, dynamic>> getProfitAndLossReport() async {
    final db = await _dbHelper.database;

    final salesRes = await db.rawQuery('''
      SELECT SUM(total_amount) as gross_sales FROM sales WHERE status != 'Voided'
    ''');
    final grossSales = (salesRes.first['gross_sales'] as num?)?.toDouble() ?? 0.0;

    final cogsRes = await db.rawQuery('''
      SELECT SUM(quantity * unit_cost_price) as cogs FROM sale_items
    ''');
    final cogs = (cogsRes.first['cogs'] as num?)?.toDouble() ?? 0.0;

    final returnsRes = await db.rawQuery('''
      SELECT SUM(total_refund) as total_refunds FROM returns
    ''');
    final totalRefunds = (returnsRes.first['total_refunds'] as num?)?.toDouble() ?? 0.0;

    final netSales = grossSales - totalRefunds;
    final grossProfit = netSales - cogs;

    return {
      'grossSales': grossSales,
      'totalRefunds': totalRefunds,
      'netSales': netSales,
      'cogs': cogs,
      'grossProfit': grossProfit,
    };
  }

  Future<List<Map<String, dynamic>>> getSalesTrendData({int days = 7}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> trendData = [];

    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = date.toIso8601String().substring(0, 10);
      final label = '${date.month}/${date.day}';

      final res = await db.rawQuery('''
        SELECT SUM(total_amount) as total 
        FROM sales 
        WHERE created_at LIKE '$dateStr%' AND status != 'Voided'
      ''');

      final amount = (res.first['total'] as num?)?.toDouble() ?? 0.0;
      trendData.add({'date': dateStr, 'label': label, 'amount': amount});
    }

    return trendData;
  }
}
