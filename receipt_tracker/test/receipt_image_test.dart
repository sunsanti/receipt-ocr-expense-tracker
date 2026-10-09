import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tracker/camera_screen.dart';
import 'package:receipt_tracker/receipt_image.dart';

void main() {
  test('normalizedFrame undoes the cover crop of the preview', () {
    // 1080x1920 preview shown in a 400x800 screen: scaled to 450x800, 25 px cut off left and right.
    final r = normalizedFrame(
      viewport: const Size(400, 800),
      preview: const Size(1080, 1920),
      frame: const Rect.fromLTWH(200, 100, 225, 400), // x 200 on screen = x 225 of the 450 px wide preview
    );
    expect(r.left, closeTo(.5, 1e-9));
    expect(r.top, closeTo(.125, 1e-9));
    expect(r.width, closeTo(.5, 1e-9));
    expect(r.height, closeTo(.5, 1e-9));
  });

  test('normalizedFrame clamps a frame bigger than the visible preview', () {
    final r = normalizedFrame(viewport: const Size(400, 800), preview: const Size(400, 800), frame: const Rect.fromLTRB(-10, -10, 500, 900));
    expect(r, const Rect.fromLTRB(0, 0, 1, 1));
  });

  test('receiptFrame is portrait, centered and fits between the bars', () {
    const screen = Size(412, 915);
    final f = receiptFrame(screen);
    expect(f.height, greaterThan(f.width));
    expect(f.center.dx, closeTo(screen.width / 2, 1e-9));
    expect(f.top, greaterThanOrEqualTo(96));
    expect(f.bottom, lessThanOrEqualTo(screen.height - 160));
  });
}
