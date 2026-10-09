import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tracker/receipt_parser.dart';

void main() {
  test('Vietnamese supermarket: picks "Tổng thanh toán", ignores subtotal/cash/change', () {
    final r = ReceiptParser.parse('''
CO.OPMART DA NANG
DC: 478 Điện Biên Phủ, Thanh Khê
MST: 0400101234
HÓA ĐƠN BÁN HÀNG
Ngày: 15/03/2025 10:24
Sữa tươi Vinamilk 2 x 32.000 64.000
Bánh mì 15.000
Tổng tiền hàng 79.000
Giảm giá 4.000
Tổng thanh toán 75.000
Tiền khách đưa 100.000
Tiền thừa 25.000
''');
    expect(r.total, 75000);
    expect(r.date, DateTime(2025, 3, 15));
    expect(r.merchant, 'CO.OPMART DA NANG');
  });

  test('café: value on the line after the label', () {
    final r = ReceiptParser.parse('''
Highlands Coffee
Vincom Đà Nẵng
Bill: 00123
12-04-2025 15:02
Trà sen vàng
45.000
TỔNG CỘNG
90.000đ
Tiền mặt
100.000đ
''');
    expect(r.total, 90000);
    expect(r.date, DateTime(2025, 4, 12));
    expect(r.merchant, 'Highlands Coffee');
  });

  test('English receipt with decimals and ISO date', () {
    final r = ReceiptParser.parse('''
CIRCLE K
Store #1234
Tel: 0236 3888 999
Date: 2025-01-07
Coffee 1.50
Subtotal 4.75
Tax 0.48
TOTAL 5.23
Cash 10.00
Change 4.77
''');
    expect(r.total, 5);
    expect(r.date, DateTime(2025, 1, 7));
    expect(r.merchant, 'CIRCLE K');
  });

  test('no keyword: falls back to largest amount, skips phone and date lines', () {
    final r = ReceiptParser.parse('''
Photocopy Thanh Tâm
ĐT: 0905123456
05/06/2025
In tài liệu 25.000
Đóng gáy 30.000
55.000
''');
    expect(r.total, 55000);
    expect(r.merchant, 'Photocopy Thanh Tâm');
  });

  test('dates: invalid day ignored, Vietnamese words, 2-digit year', () {
    expect(ReceiptParser.parse('31/02/2025').date, isNull);
    expect(ReceiptParser.parse('Ngày 05 tháng 06 năm 2025').date, DateTime(2025, 6, 5));
    expect(ReceiptParser.parse('Date 07.08.24').date, DateTime(2024, 8, 7));
    // Real ML Kit output from the sample receipt: stray space inside the date.
    expect(ReceiptParser.parse('So HD: 001245 Ngay: 08/1 0/2026').date, DateTime(2026, 10, 8));
    expect(ReceiptParser.parse('12 05/10/2025').date, DateTime(2025, 10, 5)); // clean pass wins
  });

  test('amount formats', () {
    expect(amounts('1.250.000đ'), [1250000]);
    expect(amounts('125,000 VND'), [125000]);
    expect(amounts(r'$12.50'), [13]);
    expect(amounts('12,5'), [13]);
    expect(amounts('VAT 10%'), isEmpty);
    expect(amounts('0905123456'), isEmpty);
  });

  test('normalize strips precomposed and combining diacritics', () {
    expect(normalize('TỔNG CỘNG'), 'tong cong');
    expect(normalize('Tổng'), 'tong');
  });

  test('empty text', () {
    final r = ReceiptParser.parse('');
    expect([r.total, r.date, r.merchant], [null, null, null]);
  });
}
