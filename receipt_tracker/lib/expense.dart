import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'receipt_image.dart';

const categories = ['Food', 'Study', 'Travel', 'Gear', 'Entertainment'];

class Expense {
  final int? id;
  final String merchant;
  final int amount; // VND
  final DateTime date;
  final String category;
  final String note;
  final String rawText;
  final String? thumbPath; // file name in the thumbnails folder (see receipt_image.dart)

  const Expense({
    this.id,
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    this.note = '',
    this.rawText = '',
    this.thumbPath,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'merchant': merchant,
    'amount': amount,
    'date': isoDate(date),
    'category': category,
    'note': note,
    'raw_text': rawText,
    'thumb_path': thumbPath,
  };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
    id: m['id'] as int,
    merchant: m['merchant'] as String,
    amount: m['amount'] as int,
    date: DateTime.parse(m['date'] as String),
    category: m['category'] as String,
    note: m['note'] as String? ?? '',
    rawText: m['raw_text'] as String? ?? '',
    thumbPath: m['thumb_path'] as String?,
  );
}

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _pad(int n) => n.toString().padLeft(2, '0');
String isoDate(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
String formatDate(DateTime d) => '${_pad(d.day)}/${_pad(d.month)}/${d.year}';
String formatVnd(int v) => '${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.')} đ';

class ExpenseDb {
  static Database? _db;

  static Future<Database> _open() async {
    // Web demo: same SQLite schema, compiled to WebAssembly, stored in IndexedDB
    // (web/sqlite3.wasm + web/sqflite_sw.js).
    if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;
    return _db ??= await openDatabase(
      kIsWeb ? 'expenses.db' : p.join(await getDatabasesPath(), 'expenses.db'),
      version: 2,
      onCreate: (db, _) => db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            merchant TEXT NOT NULL,
            amount INTEGER NOT NULL CHECK (amount > 0),
            date TEXT NOT NULL,
            category TEXT NOT NULL,
            note TEXT,
            raw_text TEXT,
            thumb_path TEXT)'''),
      onUpgrade: upgrade,
    );
  }

  /// v1 → v2: receipt thumbnails + the new category set.
  static Future<void> upgrade(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute('ALTER TABLE expenses ADD COLUMN thumb_path TEXT');
      await db.execute("UPDATE expenses SET category = 'Travel' WHERE category = 'Transport'");
      await db.execute("UPDATE expenses SET category = 'Entertainment' WHERE category IN ('Club', 'Other')");
    }
  }

  static Future<List<Expense>> all() async =>
      (await (await _open()).query('expenses', orderBy: 'date DESC, id DESC')).map(Expense.fromMap).toList();

  /// Insert, update (same id) or restore after undo — one upsert covers all three.
  static Future<void> save(Expense e) async =>
      (await _open()).insert('expenses', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<void> delete(int id) async => (await _open()).delete('expenses', where: 'id = ?', whereArgs: [id]);
}

/// App state: the expense history, newest first. All DB writes go through here
/// so every screen watching it (home list, totals, charts) updates together.
final expensesProvider = AsyncNotifierProvider<ExpensesNotifier, List<Expense>>(ExpensesNotifier.new);

class ExpensesNotifier extends AsyncNotifier<List<Expense>> {
  @override
  Future<List<Expense>> build() async {
    final all = await ExpenseDb.all();
    if (!kIsWeb) await purgeThumbnails({for (final e in all) ?e.thumbPath}); // also resolves thumbsPath
    return all;
  }

  /// Insert, update (same id) or restore after undo.
  Future<void> save(Expense e) async {
    await ExpenseDb.save(e);
    state = AsyncData(await ExpenseDb.all());
  }

  Future<void> delete(Expense e) async {
    state = AsyncData([...?state.value]..remove(e)); // drop it now so Dismissible doesn't see it again
    await ExpenseDb.delete(e.id!);
  }
}
