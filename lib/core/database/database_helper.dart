import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ahmad_pharmacy.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String path;
    if (kIsWeb) {
      path = filePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    final db = await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );

    // Fallback migrations for DBs created outside the versioned upgrade path
    try {
      await db.execute('ALTER TABLE customers ADD COLUMN paid_credit REAL DEFAULT 0.0');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE medicines ADD COLUMN pack_size INTEGER DEFAULT 10');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE medicines ADD COLUMN salt_composition TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE medicines ADD COLUMN requires_prescription INTEGER DEFAULT 0');
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE medicines ADD COLUMN product_type TEXT DEFAULT 'Medicine'");
    } catch (_) {}
    try {
      await db.execute("UPDATE settings SET currency_symbol = 'Rs'");
    } catch (_) {}
    try {
      await db.execute("UPDATE medicines SET pack_size = 10 WHERE (pack_size IS NULL OR pack_size <= 1) AND (LOWER(dosage_form) LIKE '%tablet%' OR LOWER(dosage_form) LIKE '%capsule%' OR LOWER(unit) LIKE '%box%' OR LOWER(unit) LIKE '%strip%' OR LOWER(unit) LIKE '%pack%')");
    } catch (_) {}

    return db;
  }

  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE medicines ADD COLUMN pack_size INTEGER DEFAULT 10');
      } catch (_) {}
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Medicines / Products
    await db.execute('''
      CREATE TABLE medicines (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        generic_name TEXT,
        sku TEXT,
        category TEXT,
        dosage_form TEXT,
        unit TEXT,
        pack_size INTEGER DEFAULT 10,
        min_stock INTEGER DEFAULT 10,
        location TEXT,
        default_price REAL DEFAULT 0.0,
        default_cost_price REAL DEFAULT 0.0,
        is_active INTEGER DEFAULT 1,
        description TEXT,
        salt_composition TEXT,
        requires_prescription INTEGER DEFAULT 0,
        product_type TEXT DEFAULT 'Medicine'
      )
    ''');

    // 2. Batches (FEFO support)
    await db.execute('''
      CREATE TABLE batches (
        id TEXT PRIMARY KEY,
        medicine_id TEXT NOT NULL,
        batch_number TEXT NOT NULL,
        expiry_date TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        buy_price REAL NOT NULL,
        sell_price REAL NOT NULL,
        received_date TEXT NOT NULL,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');

    // 3. Customers
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        total_purchases REAL DEFAULT 0.0,
        credit_balance REAL DEFAULT 0.0,
        paid_credit REAL DEFAULT 0.0,
        created_at TEXT NOT NULL
      )
    ''');

    // 4. Sales Invoices
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        invoice_no TEXT NOT NULL,
        customer_id TEXT,
        customer_name TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        tax_amount REAL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL,
        change_amount REAL DEFAULT 0.0,
        payment_method TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // 5. Sale Items
    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        medicine_id TEXT NOT NULL,
        medicine_name TEXT NOT NULL,
        generic_name TEXT,
        batch_id TEXT,
        batch_number TEXT,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        unit_cost_price REAL DEFAULT 0.0,
        discount REAL DEFAULT 0.0,
        subtotal REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    // 6. Purchases (Free-text vendor_name, NO suppliers module)
    await db.execute('''
      CREATE TABLE purchases (
        id TEXT PRIMARY KEY,
        invoice_no TEXT NOT NULL,
        vendor_name TEXT NOT NULL,
        purchase_date TEXT NOT NULL,
        subtotal REAL NOT NULL,
        tax_amount REAL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // 7. Purchase Items
    await db.execute('''
      CREATE TABLE purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL,
        medicine_id TEXT NOT NULL,
        medicine_name TEXT NOT NULL,
        batch_number TEXT NOT NULL,
        expiry_date TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        buy_price REAL NOT NULL,
        sell_price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE
      )
    ''');

    // 8. Returns
    await db.execute('''
      CREATE TABLE returns (
        id TEXT PRIMARY KEY,
        return_no TEXT NOT NULL,
        sale_id TEXT NOT NULL,
        invoice_no TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        return_date TEXT NOT NULL,
        total_refund REAL NOT NULL,
        restock_toggle INTEGER DEFAULT 1,
        notes TEXT
      )
    ''');

    // 9. Return Items
    await db.execute('''
      CREATE TABLE return_items (
        id TEXT PRIMARY KEY,
        return_id TEXT NOT NULL,
        medicine_id TEXT NOT NULL,
        medicine_name TEXT NOT NULL,
        batch_id TEXT,
        batch_number TEXT,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_refund REAL NOT NULL,
        reason TEXT NOT NULL,
        FOREIGN KEY (return_id) REFERENCES returns (id) ON DELETE CASCADE
      )
    ''');

    // 10. Stock Adjustments
    await db.execute('''
      CREATE TABLE stock_adjustments (
        id TEXT PRIMARY KEY,
        medicine_id TEXT NOT NULL,
        medicine_name TEXT NOT NULL,
        batch_id TEXT,
        batch_number TEXT,
        quantity_change INTEGER NOT NULL,
        adjustment_type TEXT NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // 11. Settings
    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY DEFAULT 1,
        pharmacy_name TEXT,
        address TEXT,
        phone TEXT,
        email TEXT,
        tax_number TEXT,
        currency_symbol TEXT,
        default_tax_rate REAL,
        default_low_stock_threshold INTEGER,
        is_dark_mode INTEGER DEFAULT 0
      )
    ''');

    // Indexes for high-frequency queries
    await db.execute('CREATE INDEX idx_batches_medicine ON batches(medicine_id)');
    await db.execute('CREATE INDEX idx_batches_expiry ON batches(expiry_date)');
    await db.execute('CREATE INDEX idx_sales_invoice ON sales(invoice_no)');
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)');
    await db.execute('CREATE INDEX idx_purchase_items_purchase ON purchase_items(purchase_id)');

    // Insert Default Settings
    await db.insert('settings', {
      'id': 1,
      'pharmacy_name': 'Ahmad Pharmacy',
      'address': '123 Medical Plaza, Suite 400',
      'phone': '+1 (555) 234-5678',
      'email': 'contact@ahmadpharmacy.com',
      'tax_number': 'TX-99887766',
      'currency_symbol': 'Rs',
      'default_tax_rate': 5.0,
      'default_low_stock_threshold': 15,
      'is_dark_mode': 0,
    });
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
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

  Future<String> exportDatabaseJson() async {
    final db = await instance.database;
    final Map<String, dynamic> exportData = {};

    final tables = [
      'medicines',
      'batches',
      'customers',
      'sales',
      'sale_items',
      'purchases',
      'purchase_items',
      'returns',
      'return_items',
      'stock_adjustments',
      'settings'
    ];

    for (final table in tables) {
      exportData[table] = await db.query(table);
    }

    return exportData.toString();
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
