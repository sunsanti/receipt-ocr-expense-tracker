// Screenshot tour on an Android emulator (wipes the app's DB — emulator only):
//   flutter drive -d emulator-5554 --driver test_driver/integration_test.dart \
//     --target integration_test/screenshots_test.dart --dart-define=PREFIX=03
// (iOS simulators can't run it: ML Kit ships no arm64-simulator slice.)
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_tracker/camera_screen.dart';
import 'package:receipt_tracker/demo_data.dart';
import 'package:receipt_tracker/expense.dart';
import 'package:receipt_tracker/main.dart';
import 'package:receipt_tracker/review_screen.dart';
import 'package:sqflite/sqflite.dart';

import 'receipt_jpg.dart';

const prefix = String.fromEnvironment('PREFIX', defaultValue: 'shot');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> shot(String name) => binding.takeScreenshot('$prefix-$name');

  /// Pumps frames until [done] or ~20 s (OCR runs on a real platform thread).
  Future<void> pumpUntil(WidgetTester t, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('screenshot tour', (t) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    final receipt = '${Directory.systemTemp.path}/receipt.jpg';
    await File(receipt).writeAsBytes(base64Decode(receiptJpgBase64));
    await deleteDatabase(p.join(await getDatabasesPath(), 'expenses.db'));
    for (final e in demoExpenses(DateTime.now())) {
      await ExpenseDb.save(e);
    }

    await t.pumpWidget(const ProviderScope(child: App()));
    await pumpUntil(t, () => find.text('Grab').evaluate().isNotEmpty);
    await t.pumpAndSettle();
    await shot('01-home');

    await t.tap(find.text('Charts'));
    await t.pump(const Duration(milliseconds: 250));
    await shot('02-charts-animating');
    await t.pumpAndSettle();
    await shot('03-charts');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await t.pumpAndSettle();
    await shot('03b-charts-categories');
    await t.tap(find.text('Expenses'));
    await t.pumpAndSettle();

    await t.tap(find.text('Scan receipt'));
    await t.pumpAndSettle();
    await shot('04-add-sheet');
    await t.tapAt(const Offset(10, 10)); // dismiss sheet
    await t.pumpAndSettle();

    // In-app camera (emulator's virtual camera): frame, tap-to-focus, flash, capture → cropped file.
    final shotPath = t.state<NavigatorState>(find.byType(Navigator)).push<String>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    await pumpUntil(t, () => find.bySemanticsLabel('Take photo').evaluate().isNotEmpty);
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 100)); // let the preview stream start
    }
    await shot('04b-camera');
    await t.tap(find.text('Flash off'));
    await t.pump(const Duration(milliseconds: 500));
    await t.tapAt(t.getCenter(find.byType(CameraPreview)) + const Offset(0, -120));
    await t.pump(const Duration(milliseconds: 150));
    await shot('04c-camera-focus-flash');
    for (final label in ['Flash auto', 'Flash on', 'Torch']) {
      await t.tap(find.text(label)); // auto → on → torch → off
      await pumpUntil(t, () => find.text(label).evaluate().isEmpty);
    }
    await t.tap(find.bySemanticsLabel('Take photo'));
    String? cropped;
    shotPath.then((p) => cropped = p);
    await pumpUntil(t, () => cropped != null);
    expect(File(cropped!).existsSync(), isTrue, reason: 'camera returns the cropped receipt');
    await t.pumpAndSettle();

    // The system photo picker can't be driven from a test, so open Review
    // directly with the picked file, as HomeScreen does after image_picker.
    t.state<NavigatorState>(find.byType(Navigator)).push(
      MaterialPageRoute(builder: (_) => ReviewScreen(imagePath: receipt)),
    );
    await t.pump(const Duration(milliseconds: 500));
    await pumpUntil(t, () => find.text('Reading receipt…').evaluate().isEmpty);
    await t.pumpAndSettle();
    await shot('05-review');

    // Inspect one OCR box: text + bounding values + "Use as …".
    await t.tap(find.bySemanticsLabel(RegExp(r'^OCR line: .*126')).first);
    await t.pumpAndSettle();
    await shot('06-box-sheet');
    await t.tap(find.text('Use as Total'));
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Zoom'));
    await t.pumpAndSettle();
    await shot('07-zoom');
    await t.tap(find.byType(CloseButton));
    await t.pumpAndSettle();

    // The tile is built lazily, so scroll the review list (not a TextField's own Scrollable).
    final page = find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('Recognized text'), 300, scrollable: page);
    await t.pumpAndSettle();
    await t.tap(find.text('Recognized text'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Parse again'));
    await t.pumpAndSettle();
    await t.pumpAndSettle();
    await shot('08-raw-text');

    await t.ensureVisible(find.text('Save expense'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save expense'));
    await t.pumpAndSettle();
    await shot('09-home-after-save');

    // Swipe to delete → Riverpod state drops it, undo restores it.
    await t.drag(find.text('Highlands Coffee'), const Offset(-500, 0));
    await t.pumpAndSettle();
    await shot('10-deleted-undo');
    await t.pump(const Duration(seconds: 5)); // let the snackbar go
    await t.pumpAndSettle();

    await t.tap(find.text('CAFE MOC VKU'));
    await t.pumpAndSettle();
    await shot('11-edit');
  });
}
