import 'expense.dart';

/// Sample history relative to [now] (current month + 5 before), used by the
/// web demo's "Load demo data" button and the screenshot tour.
List<Expense> demoExpenses(DateTime now) {
  DateTime ago(int months, int day) => DateTime(now.year, now.month - months, day);
  return [
    Expense(merchant: 'Circle K Ngu Hanh Son', amount: 45000, date: ago(0, 2), category: 'Food'),
    Expense(merchant: 'Grab', amount: 32000, date: ago(0, 3), category: 'Travel'),
    Expense(merchant: 'Nha sach Fahasa', amount: 185000, date: ago(0, 4), category: 'Study'),
    Expense(merchant: 'CLB Tin hoc – in banner', amount: 250000, date: ago(0, 5), category: 'Entertainment'),
    Expense(merchant: 'Highlands Coffee', amount: 59000, date: ago(0, 6), category: 'Food'),
    Expense(merchant: 'Ban phim co Akko', amount: 650000, date: ago(0, 1), category: 'Gear'),
    Expense(merchant: 'Bun cha ca 109', amount: 40000, date: ago(1, 12), category: 'Food'),
    Expense(merchant: 'Photocopy Thanh Tam', amount: 120000, date: ago(1, 20), category: 'Study'),
    Expense(merchant: 'Cinestar – ve xem phim', amount: 180000, date: ago(2, 8), category: 'Entertainment'),
    Expense(merchant: 'Bus 05', amount: 90000, date: ago(3, 15), category: 'Travel'),
    Expense(merchant: 'Phong Vu – tai nghe', amount: 420000, date: ago(4, 9), category: 'Gear'),
    Expense(merchant: 'Com ga A Hai', amount: 210000, date: ago(5, 21), category: 'Food'),
  ];
}
