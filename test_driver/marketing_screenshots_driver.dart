import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  final outputDirectory = Platform.environment['BLIPS_SCREENSHOT_OUTPUT_DIR'] ??
      p.join(testOutputsDirectory, 'marketing_screenshots');

  await integrationDriver(
    onScreenshot: (name, bytes, [_]) async {
      final file = File(p.join(outputDirectory, '$name.png'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    },
  );
}
