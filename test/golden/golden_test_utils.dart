/// Golden test utilities and device configurations.
///
/// Provides standard device configurations for screenshot testing
/// across different screen sizes and safe area configurations.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Standard device configurations for golden tests.
abstract final class GoldenDevices {
  /// Small phone (iPhone SE 2nd gen)
  static const smallPhone = DeviceConfig(
    name: 'small_phone',
    size: Size(375, 667),
    devicePixelRatio: 2.0,
    textScale: 1.0,
    padding: EdgeInsets.only(top: 20),
    viewPadding: EdgeInsets.only(top: 20),
  );

  /// Small phone with 1.3x text scale.
  static const smallPhoneText13 = DeviceConfig(
    name: 'small_phone_text_1_3',
    size: Size(375, 667),
    devicePixelRatio: 2.0,
    textScale: 1.3,
    padding: EdgeInsets.only(top: 20),
    viewPadding: EdgeInsets.only(top: 20),
  );

  /// Large phone (iPhone 14 Pro Max)
  static const largePhone = DeviceConfig(
    name: 'large_phone',
    size: Size(430, 932),
    devicePixelRatio: 3.0,
    textScale: 1.0,
    padding: EdgeInsets.only(top: 59, bottom: 34),
    viewPadding: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// Large phone with 1.3x text scale.
  static const largePhoneText13 = DeviceConfig(
    name: 'large_phone_text_1_3',
    size: Size(430, 932),
    devicePixelRatio: 3.0,
    textScale: 1.3,
    padding: EdgeInsets.only(top: 59, bottom: 34),
    viewPadding: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// Tablet (iPad Pro 11")
  static const tablet = DeviceConfig(
    name: 'tablet',
    size: Size(834, 1194),
    devicePixelRatio: 2.0,
    textScale: 1.0,
    padding: EdgeInsets.only(top: 24),
    viewPadding: EdgeInsets.only(top: 24),
  );

  /// iPhone with Face ID (home indicator safe area)
  static const iphoneSafeArea = DeviceConfig(
    name: 'iphone_safe',
    size: Size(393, 852),
    devicePixelRatio: 3.0,
    textScale: 1.0,
    padding: EdgeInsets.only(top: 59, bottom: 34),
    viewPadding: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// Android with gesture navigation
  static const androidGesture = DeviceConfig(
    name: 'android_gesture',
    size: Size(412, 915),
    devicePixelRatio: 2.625,
    textScale: 1.0,
    padding: EdgeInsets.only(top: 36),
    viewPadding: EdgeInsets.only(top: 36, bottom: 24),
  );

  /// Android with 3-button navigation
  static const androidButtons = DeviceConfig(
    name: 'android_buttons',
    size: Size(412, 915),
    devicePixelRatio: 2.625,
    textScale: 1.0,
    padding: EdgeInsets.only(top: 36),
    viewPadding: EdgeInsets.only(top: 36, bottom: 48),
  );

  /// Large text accessibility mode (1.5x scale)
  static const largeText = DeviceConfig(
    name: 'large_text',
    size: Size(393, 852),
    devicePixelRatio: 3.0,
    textScale: 1.5,
    padding: EdgeInsets.only(top: 59, bottom: 34),
    viewPadding: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// Extra large text accessibility mode (2.0x scale)
  static const extraLargeText = DeviceConfig(
    name: 'extra_large_text',
    size: Size(393, 852),
    devicePixelRatio: 3.0,
    textScale: 2.0,
    padding: EdgeInsets.only(top: 59, bottom: 34),
    viewPadding: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// All standard device configs for comprehensive testing.
  static const List<DeviceConfig> all = [
    smallPhone,
    largePhone,
    tablet,
    iphoneSafeArea,
    androidGesture,
    androidButtons,
    largeText,
  ];
}

/// Configuration for a test device.
class DeviceConfig {
  const DeviceConfig({
    required this.name,
    required this.size,
    required this.devicePixelRatio,
    required this.textScale,
    required this.padding,
    required this.viewPadding,
  });

  final String name;
  final Size size;
  final double devicePixelRatio;
  final double textScale;
  final EdgeInsets padding;
  final EdgeInsets viewPadding;
}

/// Extension to simplify golden test creation.
extension GoldenTestExtensions on WidgetTester {
  /// Sets up the test environment for a specific device config.
  Future<void> setDeviceConfig(DeviceConfig config) async {
    // Make golden rasterization deterministic across machines/CI by pinning the
    // test view's device pixel ratio and logical surface size.
    view.devicePixelRatio = config.devicePixelRatio;
    await binding.setSurfaceSize(config.size);

    // Configure text scaling.
    binding.platformDispatcher.textScaleFactorTestValue = config.textScale;

    // Ensure we always clean up after each test.
    addTearDown(() async {
      binding.platformDispatcher.clearTextScaleFactorTestValue();
      await binding.setSurfaceSize(null);
      view.resetDevicePixelRatio();
    });
  }
}

/// Wraps a widget with MediaQuery overrides for golden testing.
Widget goldenTestWrapper({
  required Widget child,
  required DeviceConfig device,
  Brightness brightness = Brightness.light,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: device.size,
      devicePixelRatio: device.devicePixelRatio,
      textScaler: TextScaler.linear(device.textScale),
      padding: device.padding,
      viewPadding: device.viewPadding,
      platformBrightness: brightness,
    ),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode:
          brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
      home: child,
    ),
  );
}
