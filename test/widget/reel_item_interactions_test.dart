@Tags(['widget'])
library reel_item_interactions_test;

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/reels/reel_item.dart';
import 'package:blips_mobile/features/feed/presentation/widgets/share_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../test_utils/fake_backend_api_client.dart';
import '../test_utils/feed_interaction_test_harness.dart';
import '../test_utils/recording_platforms.dart';

void main() {
  late ReelFeedEntry reel;
  late UrlLauncherPlatform originalUrlLauncher;
  late RecordingUrlLauncherPlatform recordingUrlLauncher;
  late RecordingSharePlatform recordingSharePlatform;
  late List<MethodCall> platformCalls;

  FakeBackendApiClient delayedInteractionApi() {
    return FakeBackendApiClient(
      responseResolver: (method, path, queryParameters, body) async {
        if (method == 'POST' && path == '/session/interactions') {
          await Future<void>.delayed(const Duration(seconds: 5));
        }
        return const <String, dynamic>{};
      },
    );
  }

  setUp(() {
    reel = ReelFeedEntry(
      id: 42,
      title: 'Reel interaction contract',
      summary: 'A short reel used to prove immediate actions.',
      videoUrl: 'https://www.youtube.com/shorts/abc123xyz99',
      link: 'https://www.theverge.com/2026/03/20/reel-story',
      source: 'Test Creator',
      publishedAt: DateTime.utc(2026, 3, 1),
      thumbnailUrl: 'https://example.com/reel.jpg',
    );
    originalUrlLauncher = UrlLauncherPlatform.instance;
    recordingUrlLauncher = RecordingUrlLauncherPlatform();
    UrlLauncherPlatform.instance = recordingUrlLauncher;
    recordingSharePlatform = RecordingSharePlatform();
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
    ShareService.debugOverride = ShareService.test(
      sharePlus: buildRecordingSharePlus(recordingSharePlatform),
      captureOverride: ({
        required context,
        required title,
        required summary,
        required source,
        required category,
        required date,
        required readTime,
        required imageUrl,
        required isVideo,
      }) async =>
          null,
    );
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalUrlLauncher;
    ShareService.debugOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  int selectionClickCount() => platformCalls
      .where(
        (call) =>
            call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.selectionClick',
      )
      .length;

  Future<void> settleDelayedInteraction(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
  }

  Future<void> pumpHarness(WidgetTester tester) async {
    await tester.pumpWidget(
      buildFeedInteractionHarness(
        api: delayedInteractionApi(),
        child: ReelItem(
          entry: reel,
          isActive: false,
          isVisible: false,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('share action invokes share immediately', (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.byIcon(Icons.share));
    await tester.pump(const Duration(milliseconds: 50));

    expect(recordingSharePlatform.shares, hasLength(1));
    final params = recordingSharePlatform.shares.single;
    expect(params.subject, reel.title);
    expect(params.text, contains(reel.link));
    expect(params.text, contains('Shared via Blips News'));
    expect(selectionClickCount(), 1);

    await settleDelayedInteraction(tester);
  });

  testWidgets('open action launches source immediately', (tester) async {
    await pumpHarness(tester);

    await tester.tap(find.byIcon(Icons.open_in_new));
    await tester.pump(const Duration(milliseconds: 50));

    expect(recordingUrlLauncher.launches, hasLength(1));
    expect(
      recordingUrlLauncher.launches.single.url,
      'https://www.youtube.com/shorts/abc123xyz99',
    );
    expect(selectionClickCount(), 1);

    await settleDelayedInteraction(tester);
  });
}
