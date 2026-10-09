// Regex parser engine: turns raw OCR text into Total / Date / Merchant.
// Pure Dart so it can be unit-tested without a device.

class ParsedReceipt {
  final int? total;
  final DateTime? date;
  final String? merchant;
  const ParsedReceipt({this.total, this.date, this.merchant});
}

abstract final class ReceiptParser {
  static ParsedReceipt parse(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return ParsedReceipt(total: _total(lines), date: _date(text), merchant: _merchant(lines));
  }

  /// Largest amount on one line (used when the user picks a box as the Total).
  static int? totalIn(String line) => _max(amounts(line));

  /// First valid date on one line (used when the user picks a box as the Date).
  static DateTime? dateIn(String line) => _date(line);
}

const _vn = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};
final _base = {
  for (final e in _vn.entries)
    for (final c in e.value.split('')) c: e.key,
};

/// Lowercase and strip Vietnamese diacritics (precomposed and combining marks).
String normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[̀-ͯ]'), '')
    .split('')
    .map((c) => _base[c] ?? c)
    .join();

// `.`/`,` + exactly 3 digits = thousands separator; + 1-2 digits at the end = decimals.
final _amountRe = RegExp(r'(?<![\d.,])(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)(?!\d|\s*%)');

/// All money-looking numbers on a line, rounded to whole units (VND).
List<int> amounts(String line) => [
      for (final m in _amountRe.allMatches(line))
        if (!RegExp(r'^\d{9,}$').hasMatch(m[1]!)) _value(m[1]!), // 9+ bare digits = phone/ID
    ];

int _value(String s) {
  final dec = RegExp(r'[.,](\d{1,2})$').firstMatch(s);
  final whole = int.parse((dec == null ? s : s.substring(0, dec.start)).replaceAll(RegExp('[.,]'), ''));
  return dec == null ? whole : (whole + int.parse(dec[1]!.padRight(2, '0')) / 100).round();
}

const _keywords = {
  'tong thanh toan': 3, 'tong tien thanh toan': 3, 'tong cong': 3, 'grand total': 3,
  'amount due': 3, 'total due': 3, 'khach phai tra': 3, 'can thanh toan': 3,
  'tong tien': 2, 'total': 2, 'thanh toan': 2,
  'thanh tien': 1, 'cong tien': 1, 'amount': 1,
};
final _keywordRes = {for (final e in _keywords.entries) RegExp('\\b${e.key}\\b'): e.value};

final _excluded = RegExp(r'\b(subtotal|sub total|tam tinh|tien thua|tien thoi|tra lai|change|'
    r'tien khach dua|khach dua|cash|tien mat|giam gia|chiet khau|discount|so luong|sl|qty|quantity)\b');
final _noAmountLine = RegExp(r'\b(tel|dt|sdt|hotline|phone|mst|ma so thue|tax code|so hd|invoice no)\b');

int _rank(String n) =>
    _keywordRes.entries.fold(0, (best, e) => e.key.hasMatch(n) && e.value > best ? e.value : best);

int? _max(Iterable<int> xs) => xs.where((x) => x > 0).fold<int?>(null, (m, x) => m == null || x > m ? x : m);

int? _total(List<String> lines) {
  int? best;
  var bestRank = 0;
  for (var i = 0; i < lines.length; i++) {
    final n = normalize(lines[i]);
    if (_excluded.hasMatch(n)) continue;
    final rank = _rank(n);
    if (rank == 0 || rank < bestRank) continue; // equal rank: later line wins
    var found = amounts(lines[i]);
    // OCR often puts the value on the line after its label.
    if (found.isEmpty && i + 1 < lines.length && !_excluded.hasMatch(normalize(lines[i + 1]))) {
      found = amounts(lines[i + 1]);
    }
    final v = _max(found);
    if (v != null) {
      best = v;
      bestRank = rank;
    }
  }
  if (best != null) return best;
  // ponytail: no total keyword found -> largest amount; wrong when cash given > total, user fixes it on Review.
  return _max([
    for (final l in lines)
      if (!_excluded.hasMatch(normalize(l)) && !_noAmountLine.hasMatch(normalize(l)) && _firstDate(normalize(l)) == null)
        ...amounts(l),
  ]);
}

DateTime? _date(String text) {
  final n = normalize(text);
  // OCR often splits a date with a stray space ("08/1 0/2026"); retry without
  // spaces between digits/separators, only when the clean pass found nothing.
  return _firstDate(n) ?? _firstDate(n.replaceAll(RegExp(r'(?<=[\d/.\-])\s+(?=[\d/.\-])'), ''));
}

DateTime? _firstDate(String n) {
  for (final m in RegExp(r'(?<!\d)(\d{4})[/.\-](\d{1,2})[/.\-](\d{1,2})(?!\d)').allMatches(n)) {
    final d = _valid(m[1]!, m[2]!, m[3]!);
    if (d != null) return d;
  }
  for (final m in RegExp(r'(?<!\d)(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})(?!\d)').allMatches(n)) {
    final d = _valid(m[3]!, m[2]!, m[1]!);
    if (d != null) return d;
  }
  for (final m in RegExp(r'ngay\s*(\d{1,2})\s*thang\s*(\d{1,2})\s*nam\s*(\d{4})').allMatches(n)) {
    final d = _valid(m[3]!, m[2]!, m[1]!);
    if (d != null) return d;
  }
  return null;
}

DateTime? _valid(String ys, String ms, String ds) {
  var y = int.parse(ys);
  if (y < 100) y += 2000;
  final m = int.parse(ms), d = int.parse(ds);
  final dt = DateTime(y, m, d);
  if (dt.month != m || dt.day != d || y < 2000 || y > DateTime.now().year + 1) return null;
  return dt;
}

final _notMerchant = RegExp(r'\b(dc|d/c|dia chi|address|addr|mst|ma so thue|tax|hoa don|invoice|receipt|'
    r'bill|phieu|tel|dt|sdt|hotline|phone|website|www|xin chao|welcome|cam on|thank|store)\b');

String? _merchant(List<String> lines) {
  for (final l in lines.take(5)) {
    final n = normalize(l);
    final letters = RegExp('[a-z]').allMatches(n).length;
    final digits = RegExp(r'\d').allMatches(n).length;
    if (letters < 3 || digits > letters) continue;
    if (_notMerchant.hasMatch(n) || RegExp(r'^\d+[\s/,]').hasMatch(n) || _firstDate(n) != null) continue;
    return l;
  }
  return null;
}
