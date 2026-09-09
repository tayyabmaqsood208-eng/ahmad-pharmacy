import 'dart:math' as math;
import '../models/customer.dart';
import '../../core/database/database_helper.dart';

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Customer>> getCustomers({String? query, bool? hasCreditOnly}) async {
    final db = await _dbHelper.database;

    await _syncCustomerBalances(db);

    String whereClause = 'WHERE 1=1';
    List<dynamic> whereArgs = [];

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      whereClause += ' AND (LOWER(name) LIKE ? OR LOWER(phone) LIKE ? OR LOWER(email) LIKE ?)';
      whereArgs.addAll([q, q, q]);
    }

    if (hasCreditOnly == true) {
      whereClause += ' AND credit_balance > 0';
    }

    final maps = await db.rawQuery(
      'SELECT * FROM customers $whereClause ORDER BY name ASC',
      whereArgs,
    );

    return maps.map((map) => Customer.fromMap(map)).toList();
  }

  Future<void> _syncCustomerBalances(dynamic db) async {
    try {
      final customers = await db.query('customers');
      final sales = await db.query('sales', where: "status != 'Voided'");
      final returns = await db.query('returns');

      for (final custMap in customers) {
        final custId = custMap['id'] as String;
        final custName = (custMap['name'] as String).trim().toLowerCase();
        final currentPurchases = (custMap['total_purchases'] as num?)?.toDouble() ?? 0.0;
        final currentCredit = (custMap['credit_balance'] as num?)?.toDouble() ?? 0.0;
        final paidCredit = (custMap['paid_credit'] as num?)?.toDouble() ?? 0.0;

        double calculatedPurchases = 0.0;
        double calculatedCreditSales = 0.0;

        for (final saleMap in sales) {
          final saleCustId = saleMap['customer_id'] as String?;
          final saleCustName = (saleMap['customer_name'] as String? ?? '').trim().toLowerCase();
          final paymentMethod = saleMap['payment_method'] as String? ?? '';
          final totalAmount = (saleMap['total_amount'] as num?)?.toDouble() ?? 0.0;
          final saleId = saleMap['id'] as String;

          bool isMatch = false;

          if (saleCustId != null && saleCustId == custId) {
            isMatch = true;
          } else if ((saleCustId == null || saleCustId.isEmpty) && saleCustName.isNotEmpty && saleCustName != 'walk-in customer') {
            if (saleCustName == custName || custName.startsWith(saleCustName) || saleCustName.startsWith(custName)) {
              isMatch = true;
              await db.update('sales', {'customer_id': custId}, where: 'id = ?', whereArgs: [saleId]);
            }
          }

          if (isMatch) {
            calculatedPurchases += totalAmount;
            if (paymentMethod == 'Credit' || paymentMethod == 'Store Credit') {
              calculatedCreditSales += totalAmount;
            }
          }
        }

        double calculatedRefunds = 0.0;
        for (final retMap in returns) {
          final retCustId = retMap['customer_id'] as String?;
          final retCustName = (retMap['customer_name'] as String? ?? '').trim().toLowerCase();
          final retInvoiceNo = (retMap['invoice_no'] as String? ?? '').trim();
          final refundAmount = (retMap['total_refund_amount'] as num?)?.toDouble() ?? 0.0;

          bool isMatch = false;
          if (retCustId != null && retCustId == custId) {
            isMatch = true;
          } else if (retCustName.isNotEmpty && retCustName != 'walk-in customer') {
            if (retCustName == custName || custName.startsWith(retCustName) || retCustName.startsWith(custName)) {
              isMatch = true;
              if (retCustId == null || retCustId.isEmpty) {
                await db.update('returns', {'customer_id': custId}, where: 'id = ?', whereArgs: [retMap['id']]);
              }
            }
          }

          if (!isMatch && retInvoiceNo.isNotEmpty) {
            for (final saleMap in sales) {
              final saleInvoice = (saleMap['invoice_no'] as String? ?? '').trim();
              final saleCustId = saleMap['customer_id'] as String?;
              final saleCustName = (saleMap['customer_name'] as String? ?? '').trim().toLowerCase();

              if (saleInvoice == retInvoiceNo) {
                if (saleCustId == custId || (saleCustName.isNotEmpty && (saleCustName == custName || custName.startsWith(saleCustName)))) {
                  isMatch = true;
                  break;
                }
              }
            }
          }

          if (isMatch) {
            calculatedRefunds += refundAmount;
          }
        }

        final calcPurchasesRounded = (math.max(0.0, calculatedPurchases - calculatedRefunds) * 100).roundToDouble() / 100.0;
        final netOutstandingDebt = (math.max(0.0, calculatedCreditSales - paidCredit - calculatedRefunds) * 100).roundToDouble() / 100.0;

        if (calcPurchasesRounded != currentPurchases || netOutstandingDebt != currentCredit) {
          await db.update(
            'customers',
            {
              'total_purchases': calcPurchasesRounded,
              'credit_balance': netOutstandingDebt,
            },
            where: 'id = ?',
            whereArgs: [custId],
          );
        }
      }
    } catch (_) {
      // Ignore sync errors gracefully
    }
  }

  Future<void> addCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    await db.insert('customers', customer.toMap());
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> payCustomerCredit(String customerId, double paymentAmount) async {
    final db = await _dbHelper.database;
    final roundedAmount = (paymentAmount * 100).roundToDouble() / 100.0;
    await db.rawUpdate(
      'UPDATE customers SET paid_credit = ROUND(COALESCE(paid_credit, 0.0) + ?, 2), credit_balance = MAX(0, ROUND(credit_balance - ?, 2)) WHERE id = ?',
      [roundedAmount, roundedAmount, customerId],
    );
  }

  Future<void> deleteCustomer(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
