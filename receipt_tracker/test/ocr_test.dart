import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tracker/ocr.dart';
import 'package:receipt_tracker/review_screen.dart';

void main() {
  test('joinRows merges label and price columns into rows', () {
    final text = joinRows([
      ('TOTAL', const Rect.fromLTWH(10, 100, 60, 20)),
      ('Coffee', const Rect.fromLTWH(10, 50, 60, 20)),
      ('90.000', const Rect.fromLTWH(200, 103, 60, 20)), // slightly lower, same row
      ('45.000', const Rect.fromLTWH(200, 48, 60, 20)),
    ]);
    expect(text, 'Coffee 45.000\nTOTAL 90.000');
  });

  test('fieldOf colors the boxes that feed each field', () {
    final f = DateTime(2026, 10, 8);
    Field? of(String line) => fieldOf(line, total: 126000, date: f, merchant: 'CAFE MOC VKU');
    expect(of('126.000'), Field.total);
    expect(of('Ngay: 08/10/2026'), Field.date);
    expect(of('CAFE MOC VKU'), Field.merchant);
    expect(of('MOC'), Field.merchant); // part of a merchant row split by OCR
    expect(of('140.000'), isNull);
    expect(of('VK'), isNull); // too short to claim
    expect(fieldOf('CAFE', total: null), isNull); // empty merchant matches nothing
  });
}
