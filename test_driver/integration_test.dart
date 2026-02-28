import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart'
    as driver;

/// Custom driver that saves screenshots to store_metadata/screenshots/.
///
/// Usage:
/// ```bash
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/screenshot_test.dart \
///   -d <device-id>
/// ```
Future<void> main() async {
  final outputDir = Directory('store_metadata/screenshots');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  await driver.integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('${outputDir.path}/$name.png');
      file.writeAsBytesSync(bytes);
      // ignore: avoid_print
      print('Screenshot saved: ${file.path}');
      return true;
    },
  );
}
