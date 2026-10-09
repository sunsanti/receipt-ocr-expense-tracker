import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Writes every `binding.takeScreenshot(name)` to ../screenshots/name.png.
Future<void> main() => integrationDriver(onScreenshot: (name, bytes, [args]) async {
      await File('../screenshots/$name.png').writeAsBytes(bytes);
      return true;
    });
