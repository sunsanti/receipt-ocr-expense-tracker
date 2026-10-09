import 'dart:io';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// One recognized line and where it sits on the photo (image pixels).
typedef OcrLine = (String text, Rect box);

class OcrResult {
  /// Row-joined text (see [joinRows]), the input for the receipt parser.
  final String text;
  final List<OcrLine> lines;

  /// Size of the decoded photo, to scale [lines] boxes onto the displayed image.
  final Size imageSize;

  /// Time ML Kit spent recognizing text (excludes decoding the photo for display).
  final Duration elapsed;
  const OcrResult(this.text, this.lines, this.imageSize, this.elapsed);
}

// One recognizer for the app's lifetime: the model loads on the first scan
// only, so later scans skip that cost.
final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

/// On-device OCR with ML Kit's [TextRecognizer].
Future<OcrResult> recognizeText(String imagePath) async {
  final clock = Stopwatch()..start();
  final result = await _recognizer.processImage(InputImage.fromFilePath(imagePath));
  clock.stop();
  final lines = [
    for (final b in result.blocks)
      for (final l in b.lines) (l.text, l.boundingBox),
  ];
  return OcrResult(joinRows(lines), lines, await _imageSize(imagePath), clock.elapsed);
}

// Full decode (not just the header) so EXIF rotation is applied, matching both
// ML Kit's box coordinates and how Image.file draws the photo.
Future<Size> _imageSize(String path) async {
  final frame = await (await instantiateImageCodec(await File(path).readAsBytes())).getNextFrame();
  final size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
  frame.image.dispose();
  return size;
}

/// ML Kit groups text into blocks (often a label column and a price column),
/// so "TOTAL" and "90.000" land far apart. Re-join lines that sit on the same
/// visual row, left to right.
// ponytail: assumes the photo is roughly upright; tilted receipts merge or split rows.
String joinRows(List<OcrLine> lines) {
  final sorted = [...lines]..sort((a, b) => a.$2.center.dy.compareTo(b.$2.center.dy));
  final rows = <List<OcrLine>>[];
  for (final l in sorted) {
    final first = rows.isEmpty ? null : rows.last.first.$2;
    if (first != null && (l.$2.center.dy - first.center.dy).abs() < first.height / 2) {
      rows.last.add(l);
    } else {
      rows.add([l]);
    }
  }
  return rows
      .map((r) => (r..sort((a, b) => a.$2.left.compareTo(b.$2.left))).map((l) => l.$1).join(' '))
      .join('\n');
}
