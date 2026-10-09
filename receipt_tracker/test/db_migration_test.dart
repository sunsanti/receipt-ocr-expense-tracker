import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tracker/expense.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('v1 → v2 keeps rows, adds thumb_path, maps old categories', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, merchant TEXT NOT NULL, '
                'amount INTEGER NOT NULL CHECK (amount > 0), date TEXT NOT NULL, category TEXT NOT NULL, note TEXT, raw_text TEXT)');
            for (final c in ['Food', 'Transport', 'Study', 'Club', 'Other']) {
              await db.insert('expenses', {'merchant': c, 'amount': 1000, 'date': '2026-10-01', 'category': c});
            }
          },
        ));
    await ExpenseDb.upgrade(db, 1, 2);
    final rows = (await db.query('expenses', orderBy: 'id')).map(Expense.fromMap).toList();
    expect(rows.map((e) => e.category), ['Food', 'Travel', 'Study', 'Entertainment', 'Entertainment']);
    expect(rows.every((e) => e.thumbPath == null && e.amount == 1000), isTrue);
    expect(rows.every((e) => categories.contains(e.category)), isTrue);
    await db.close();
  });
}
