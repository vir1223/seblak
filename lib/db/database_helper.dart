import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// DatabaseHelper
/// ---------------------------------------------------------------------
/// Pusat penyimpanan data lokal (SQLite) untuk menggantikan Firebase
/// (Cloud Firestore untuk data & Firebase Auth untuk login).
///
/// Menggunakan pola Singleton supaya hanya ada 1 koneksi database
/// yang dipakai di seluruh aplikasi.
/// ---------------------------------------------------------------------
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  /// Nama file database & versi skema.
  /// PENTING: setiap kali menambah/mengubah tabel di masa depan,
  /// naikkan angka _dbVersion ini dan tambahkan langkah migrasinya
  /// di _onUpgrade -- supaya HP yang sudah ter-install aplikasi lama
  /// ikut mendapat perubahan skema tanpa perlu uninstall.
  static const String _dbName = 'seblak_app.db';
  static const int _dbVersion = 3;

  /// Getter utama, dipanggil setiap butuh akses DB.
  /// Otomatis membuka (dan membuat) database jika belum ada.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbDir = await getDatabasesPath();
    final dbPath = join(dbDir, _dbName);

    return openDatabase(
      dbPath,
      version: _dbVersion,
      onConfigure: (db) async {
        // Aktifkan foreign key constraint (mis. order_items -> orders)
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ---------------- USERS (pengganti Firebase Auth) ----------------
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    // ---------------- PRODUCTS (pengganti collection 'products') ------
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        harga INTEGER NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // ---------------- ORDERS (pengganti collection 'orders') ----------
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_amount REAL NOT NULL,
        amount_paid REAL NOT NULL,
        change_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        order_date TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    // ---------------- ORDER_ITEMS (dulu array 'orderItems' di Firestore)
    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        price_at_order INTEGER NOT NULL,
        subtotal INTEGER NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    // ---------------- SETTINGS (key-value, mis. nama toko, QRIS) ------
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // ---------------- DEBTS (hutang pelanggan) -------------------------
    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        is_paid INTEGER NOT NULL DEFAULT 0,
        paid_at TEXT
      )
    ''');

    // ---------------- EXPENSES (pengeluaran toko) -----------------------
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Seed akun default supaya bisa langsung login setelah migrasi.
    // Username: admin | Password: admin123
    // -> Sebaiknya ganti password ini setelah aplikasi berjalan.
    await db.insert('users', {
      'username': 'admin',
      'password': _hashPassword('admin123'),
    });

    // Seed nama toko default
    await db.insert('settings', {
      'key': 'store_name',
      'value': 'Kasir Seblak',
    });
  }

  /// Migrasi skema untuk HP yang sudah lebih dulu install aplikasi
  /// versi lama (sebelum tabel 'settings'/'debts'/'expenses' ada).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await db.insert(
        'settings',
        {'key': 'store_name', 'value': 'Kasir Seblak'},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS debts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_name TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          is_paid INTEGER NOT NULL DEFAULT 0,
          paid_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  // =====================================================================
  // AUTH (pengganti FirebaseAuth.instance.signInWithEmailAndPassword)
  // =====================================================================

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Mengembalikan true jika username & password cocok.
  Future<bool> login(String username, String password) async {
    final db = await database;
    final hashed = _hashPassword(password);
    final result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, hashed],
    );
    return result.isNotEmpty;
  }

  /// Ganti password user (opsional, untuk pengembangan lanjutan).
  Future<int> changePassword(String username, String newPassword) async {
    final db = await database;
    return db.update(
      'users',
      {'password': _hashPassword(newPassword)},
      where: 'username = ?',
      whereArgs: [username],
    );
  }

  // =====================================================================
  // SETTINGS (key-value store, mis. nama toko yang tampil di AppBar)
  // =====================================================================

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (result.isEmpty) return null;
    return result.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  // =====================================================================
  // PRODUCTS (pengganti collection('products'))
  // =====================================================================

  Future<int> insertProduct(String nama, int harga, {int stock = 0}) async {
    final db = await database;
    return db.insert('products', {
      'nama': nama,
      'harga': harga,
      'stock': stock,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// [orderBy] default urut berdasarkan tanggal dibuat (ASC), bisa
  /// diganti mis. 'nama ASC' untuk halaman kasir.
  Future<List<Map<String, dynamic>>> getAllProducts({
    String orderBy = 'created_at ASC',
  }) async {
    final db = await database;
    return db.query('products', orderBy: orderBy);
  }

  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await database;
    final result = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateProduct(int id, {required String nama, required int harga}) async {
    final db = await database;
    return db.update(
      'products',
      {'nama': nama, 'harga': harga},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateStock(int id, int newStock) async {
    final db = await database;
    return db.update(
      'products',
      {'stock': newStock},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  /// Produk dengan stok <= [threshold], diurutkan dari yang paling
  /// sedikit. Dipakai untuk quick-action peringatan stok menipis
  /// di home_page.dart.
  Future<List<Map<String, dynamic>>> getLowStockProducts({int threshold = 5}) async {
    final db = await database;
    return db.query(
      'products',
      where: 'stock <= ?',
      whereArgs: [threshold],
      orderBy: 'stock ASC',
    );
  }

  // =====================================================================
  // CHECKOUT / ORDERS (pengganti WriteBatch di bayar_page.dart)
  // =====================================================================

  /// Memproses transaksi kasir secara ATOMIK menggunakan SQLite transaction:
  /// 1. Cek ulang stok terbaru langsung dari database.
  /// 2. Buat 1 baris di 'orders'.
  /// 3. Buat baris item di 'order_items' untuk tiap produk di keranjang.
  /// 4. Kurangi stok tiap produk.
  ///
  /// Jika salah satu produk stoknya tidak cukup, SEMUA proses dibatalkan
  /// (rollback otomatis) dan Exception dilempar -- persis seperti
  /// logika pengecekan manual di bayar_page.dart versi Firebase.
  ///
  /// Mengembalikan [id] order yang baru dibuat.
  Future<int> checkout({
    required Map<int, int> cart, // productId -> quantity
    required Map<int, Map<String, dynamic>> cartDetails, // productId -> {name, price, stock}
    required double totalAmount,
    required double amountPaid,
    required double changeAmount,
    required String paymentMethod,
  }) async {
    final db = await database;
    late int orderId;

    await db.transaction((txn) async {
      // 1. Validasi stok terbaru (bukan dari cache di memori)
      for (final entry in cart.entries) {
        final productId = entry.key;
        final qty = entry.value;

        final rows = await txn.query('products', where: 'id = ?', whereArgs: [productId]);
        if (rows.isEmpty) {
          throw Exception('Produk tidak ditemukan: ID $productId.');
        }

        final currentStock = rows.first['stock'] as int;
        final namaProduk = rows.first['nama'] as String;

        if (currentStock < qty) {
          throw Exception('Gagal: Stok untuk $namaProduk tidak cukup. Tersisa: $currentStock');
        }
      }

      // 2. Buat header order
      orderId = await txn.insert('orders', {
        'total_amount': totalAmount,
        'amount_paid': amountPaid,
        'change_amount': changeAmount,
        'payment_method': paymentMethod,
        'order_date': DateTime.now().toIso8601String(),
        'status': 'Completed',
      });

      // 3. Insert item order + kurangi stok
      for (final entry in cart.entries) {
        final productId = entry.key;
        final qty = entry.value;
        final detail = cartDetails[productId]!;
        final price = detail['price'] as int;
        final nama = detail['name'] as String;

        await txn.insert('order_items', {
          'order_id': orderId,
          'product_id': productId,
          'name': nama,
          'quantity': qty,
          'price_at_order': price,
          'subtotal': price * qty,
        });

        final rows = await txn.query('products', where: 'id = ?', whereArgs: [productId]);
        final currentStock = rows.first['stock'] as int;

        await txn.update(
          'products',
          {'stock': currentStock - qty},
          where: 'id = ?',
          whereArgs: [productId],
        );
      }
    });

    return orderId;
  }

  /// Ambil daftar order. Jika [startDate] & [endDate] diisi, difilter
  /// sesuai rentang tanggal (dipakai di lapor_page.dart).
  Future<List<Map<String, dynamic>>> getOrders({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    if (startDate != null && endDate != null) {
      return db.query(
        'orders',
        where: 'order_date >= ? AND order_date < ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'order_date DESC',
      );
    }
    return db.query('orders', orderBy: 'order_date DESC');
  }

  Future<Map<String, dynamic>?> getOrderById(int id) async {
    final db = await database;
    final result = await db.query('orders', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getOrderItems(int orderId) async {
    final db = await database;
    return db.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
  }

  /// Total penjualan per bulan untuk [monthsBack] bulan terakhir
  /// (termasuk bulan berjalan). Bulan yang tidak ada transaksi tetap
  /// disertakan dengan total 0, supaya grafik tidak terputus-putus.
  /// Dipakai untuk grafik penjualan bulanan di home_page.dart.
  Future<List<Map<String, dynamic>>> getMonthlySales({int monthsBack = 6}) async {
    final db = await database;
    final now = DateTime.now();
    final firstMonth = DateTime(now.year, now.month - (monthsBack - 1), 1);

    final rows = await db.rawQuery('''
      SELECT strftime('%Y-%m', order_date) as month, SUM(total_amount) as total
      FROM orders
      WHERE order_date >= ?
      GROUP BY month
      ORDER BY month ASC
    ''', [firstMonth.toIso8601String()]);

    final Map<String, double> salesMap = {
      for (final row in rows)
        row['month'] as String: (row['total'] as num?)?.toDouble() ?? 0.0
    };

    final List<Map<String, dynamic>> result = [];
    for (int i = 0; i < monthsBack; i++) {
      final monthDate = DateTime(firstMonth.year, firstMonth.month + i, 1);
      final key =
          '${monthDate.year.toString().padLeft(4, '0')}-${monthDate.month.toString().padLeft(2, '0')}';
      result.add({
        'month': key,
        'monthDate': monthDate,
        'total': salesMap[key] ?? 0.0,
      });
    }
    return result;
  }

  // =====================================================================
  // DEBTS / HUTANG (pencatatan hutang pelanggan)
  // =====================================================================

  Future<int> insertDebt({
    required String customerName,
    required double amount,
    String? note,
  }) async {
    final db = await database;
    return db.insert('debts', {
      'customer_name': customerName,
      'amount': amount,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
      'is_paid': 0,
      'paid_at': null,
    });
  }

  /// [onlyUnpaid] true -> hanya hutang yang belum lunas.
  /// Diurutkan: yang belum lunas duluan, lalu dari yang terbaru.
  Future<List<Map<String, dynamic>>> getDebts({bool onlyUnpaid = false}) async {
    final db = await database;
    if (onlyUnpaid) {
      return db.query(
        'debts',
        where: 'is_paid = 0',
        orderBy: 'created_at DESC',
      );
    }
    return db.query('debts', orderBy: 'is_paid ASC, created_at DESC');
  }

  Future<int> markDebtAsPaid(int id) async {
    final db = await database;
    return db.update(
      'debts',
      {'is_paid': 1, 'paid_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDebt(int id) async {
    final db = await database;
    return db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  /// Total seluruh hutang yang belum lunas.
  Future<double> getTotalUnpaidDebt() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM debts WHERE is_paid = 0",
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // =====================================================================
  // EXPENSES / PENGELUARAN (pencatatan pengeluaran toko)
  // =====================================================================

  Future<int> insertExpense({
    required String description,
    required double amount,
    String? category,
  }) async {
    final db = await database;
    return db.insert('expenses', {
      'description': description,
      'amount': amount,
      'category': category,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    if (startDate != null && endDate != null) {
      return db.query(
        'expenses',
        where: 'created_at >= ? AND created_at < ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'created_at DESC',
      );
    }
    return db.query('expenses', orderBy: 'created_at DESC');
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  /// Total pengeluaran dalam rentang tanggal tertentu (opsional).
  Future<double> getTotalExpenses({DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    if (startDate != null && endDate != null) {
      final result = await db.rawQuery(
        "SELECT SUM(amount) as total FROM expenses WHERE created_at >= ? AND created_at < ?",
        [startDate.toIso8601String(), endDate.toIso8601String()],
      );
      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    }
    final result = await db.rawQuery("SELECT SUM(amount) as total FROM expenses");
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Tutup koneksi database (opsional, jarang dibutuhkan di mobile app).
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
