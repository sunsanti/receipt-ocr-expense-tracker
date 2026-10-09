import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tracker/charts.dart';
import 'package:receipt_tracker/expense.dart';

Expense e(int amount, DateTime date, [String category = 'Food']) =>
    Expense(merchant: 'x', amount: amount, date: date, category: category);

void main() {
  final xs = [
    e(50000, DateTime(2025, 12, 29)), // Mon: week of 29/12/2024–4/1, crosses the year
    e(20000, DateTime(2026, 1, 4), 'Travel'), // Sun, same week
    e(30000, DateTime(2026, 1, 5)), // next Monday → next week
    e(10000, DateTime(2025, 12, 21)), // Sun, two weeks back
    e(99000, DateTime(2025, 1, 1)), // far outside the window
  ];

  test('weekStart is the Monday', () {
    expect(weekStart(DateTime(2026, 1, 4)), DateTime(2025, 12, 29));
    expect(weekStart(DateTime(2026, 1, 5)), DateTime(2026, 1, 5));
  });

  test('weeklyTotals: Monday–Sunday buckets across the year boundary, oldest first', () {
    final w = weeklyTotals(xs, DateTime(2026, 1, 7), weeks: 4);
    expect(w.map((x) => x.$1), [DateTime(2025, 12, 15), DateTime(2025, 12, 22), DateTime(2025, 12, 29), DateTime(2026, 1, 5)]);
    expect(w.map((x) => x.$2), [10000, 0, 70000, 30000]);
  });

  test('categoryTotals for a week, largest first', () {
    expect(categoryTotals(xs, DateTime(2025, 12, 29), DateTime(2026, 1, 5)), [('Food', 50000), ('Travel', 20000)]);
    expect(categoryTotals(xs, DateTime(2025, 12, 22), DateTime(2025, 12, 29)), isEmpty);
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
      home: Scaffold(body: ChartsView(expenses: [e(50000, now), e(20000, now, 'Gear'), e(9000, now.subtract(const Duration(days: 21)))])),
    ));
    await t.pump(const Duration(milliseconds: 200));
    final bars = t.widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BarChartPainter));
    expect((bars.painter! as BarChartPainter).progress, inExclusiveRange(0, 1));
    await t.pumpAndSettle();
    expect(find.text('By category'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
