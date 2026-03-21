@Tags(['widget'])
library settings_page_test;

import 'package:blips_mobile/core/diagnostics/app_diagnostics.dart';
import 'package:blips_mobile/core/theme/app_theme.dart';
import 'package:blips_mobile/features/settings/presentation/settings_page.dart';
import 'package:blips_mobile/features/settings/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../test_utils/recording_platforms.dart';

void main() {
  late UrlLauncherPlatform originalUrlLauncher;
  late RecordingUrlLauncherPlatform recordingUrlLauncher;
  String? clipboardText;

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    originalUrlLauncher = UrlLauncherPlatform.instance;
    recordingUrlLauncher = RecordingUrlLauncherPlatform();
    UrlLauncherPlatform.instance = recordingUrlLauncher;
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          final arguments = (call.arguments as Map<Object?, Object?>?) ??
              const <Object?, Object?>{};
          clipboardText = arguments['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return <String, Object?>{'text': clipboardText};
      }
      return null;
    });
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalUrlLauncher;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget buildTestWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MediaQuery(
        data: MediaQueryData(
          size: Size(430, 1200),
          devicePixelRatio: 1,
        ),
        child: MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );
  }

  testWidgets('theme mode tiles update the selected app theme', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.light);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.dark);

    await tester.tap(find.text('Neon'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), AppThemeMode.neon);
  });

  testWidgets('policy shortcuts launch the correct URLs', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy'));
    await tester.pump();
    await tester.tap(find.text('Terms'));
    await tester.pump();
    await tester.tap(find.text('Support'));
    await tester.pump();

    expect(recordingUrlLauncher.launches, hasLength(3));
    expect(
      recordingUrlLauncher.launches.map((launch) => launch.url),
      containsAll(<String>[
        'https://blips.tech/privacy.html',
        'https://blips.tech/terms.html',
        'https://blips.tech/support.html',
      ]),
    );
  });

  testWidgets('clear chat history opens a confirmation dialog', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear Chat History'));
    await tester.pumpAndSettle();

    expect(find.text('Clear History?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Clear History?'), findsNothing);
  });

  testWidgets('delete my data opens a confirmation dialog', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete My Data'));
    await tester.pumpAndSettle();

    expect(find.text('Delete My Data?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete My Data?'), findsNothing);
  });

  testWidgets('diagnostics actions copy and clear buffered events', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final diagnostics = container.read(appDiagnosticsProvider);
    diagnostics.record(
      scope: 'feed.notifier',
      action: 'manualRefresh',
      stage: 'failure',
      surface: 'articles',
      data: const <String, Object?>{'statusCode': 504},
    );

    await tester.pumpWidget(buildTestWidget(container));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Copy diagnostics log'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy diagnostics log'));
    await tester.pump();

    expect(clipboardText, contains('manualRefresh.failure'));

    await tester.tap(find.text('Clear diagnostics'));
    await tester.pump();

    expect(diagnostics.count, 0);
  });
}
