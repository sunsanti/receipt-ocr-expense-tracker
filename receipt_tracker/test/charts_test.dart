import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tracker/charts.dart';
import 'package:receipt_tracker/expense.dart';

Expense e(int amount, DateTime date, [String category = 'Food']) =>
    Expense(merchant: 'x', amount: amount, date: date, category: category);

void main() {
  final xs = [
    e(50000, DateTime(2025, 3, 2)),
    e(20000, DateTime(2025, 3, 20), 'Transport'),
    e(30000, DateTime(2025, 3, 21)),
    e(10000, DateTime(2025, 1, 5)),
    e(99000, DateTime(2024, 3, 5)), // same month, other year: must not count
  ];

  test('monthlyTotals spans year boundary, oldest first', () {
    final m = monthlyTotals(xs, DateTime(2025, 3, 15), months: 4);
    expect(m.map((x) => x.$1), [DateTime(2024, 12), DateTime(2025, 1), DateTime(2025, 2), DateTime(2025, 3)]);
    expect(m.map((x) => x.$2), [0, 10000, 0, 100000]);
  });

  test('categoryTotals sorted largest first', () {
    expect(categoryTotals(xs, DateTime(2025, 3)), [('Food', 80000), ('Transport', 20000)]);
    expect(categoryTotals(xs, DateTime(2025, 2)), isEmpty);
  });

  test('formatting', () {
    expect(formatVnd(1250000), '1.250.000 đ');
    expect(formatVnd(500), '500 đ');
    expect(compactVnd(1500000), '1.5M');
    expect(compactVnd(75000), '75K');
  });

  testWidgets('charts paint mid-animation and settle', (t) async {
    final now = DateTime.now();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: ChartsView(expenses: [e(50000, now), e(20000, now, 'Club'), e(9000, DateTime(now.year, now.month - 2))])),
    ));
    await t.pump(const Duration(milliseconds: 200));
    final bars = t.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BarChartPainter));
    expect((bars.painter! as BarChartPainter).progress, inExclusiveRange(0, 1));
    await t.pumpAndSettle();
    expect(find.text('By category'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
