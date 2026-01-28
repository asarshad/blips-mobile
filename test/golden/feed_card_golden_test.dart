/// Golden tests for feed cards.
///
/// Covers layout regressions across:
/// - Small vs large phones
/// - Text scale 1.0 vs 1.3
@Tags(['golden'])
library;

import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/presentation/cards/article_card.dart';
import 'package:blips_mobile/features/feed/presentation/cards/video_card.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:network_image_mock/network_image_mock.dart';

import '../test_utils/fake_youtube_player_manager.dart';
import 'golden_test_utils.dart';

void main() {
  // CI (macos-14-arm64) can produce tiny, harmless pixel drift for a specific
  // golden. Keep everything else strict.
  installAllowlistedGoldenToleranceComparator(
    allowlist: {
      RegExp(r'goldens/feed_article_large_1_0\.png$'): const GoldenTolerance(
        maxDiffPercent: 0.05,
        maxDiffPixels: 200,
      ),
    },
  );

  group('Feed Card Golden Tests', () {
    final article = ArticleFeedEntry(
      id: 1,
      title:
          'This is a long-ish article title to validate wrapping and truncation',
      summary:
          'A short summary that should fit comfortably while still exercising multi-line layout.',
      source: 'example.com',
      publishedAt: DateTime.utc(2025, 1, 1),
      url: 'https://example.com/article',
      imageUrl: 'https://example.com/image.png',
      category: 'Technology',
      readTime: 5,
      tags: const ['Technology', 'AI'],
    );

    final video = VideoFeedEntry(
      id: 2,
      title: 'Video title that is also long enough to wrap on small screens',
      summary:
          'Video summary to validate typography and spacing in the feed card frame.',
      videoUrl: 'https://cdn.example.com/video.mp4',
      link: 'https://youtube.com/watch?v=dQw4w9WgXcQ',
      thumbnailUrl: 'https://example.com/thumb.png',
      source: 'YouTube',
      category: 'Technology',
      publishedAt: DateTime.utc(2025, 1, 2),
      readTime: 3,
    );

    final cases = <({DeviceConfig device, String suffix})>[
      (device: GoldenDevices.smallPhone, suffix: 'small_1_0'),
      (device: GoldenDevices.smallPhoneText13, suffix: 'small_1_3'),
      (device: GoldenDevices.largePhone, suffix: 'large_1_0'),
      (device: GoldenDevices.largePhoneText13, suffix: 'large_1_3'),
    ];

    for (final c in cases) {
      testWidgets('ArticleCard ${c.suffix}', (tester) async {
        await tester.setDeviceConfig(c.device);

        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            goldenTestWrapper(
              device: c.device,
              child: Scaffold(
                body: ArticleCard(entry: article),
              ),
            ),
          );
          // Avoid pumpAndSettle here because some widgets (e.g. InkWell) can
          // schedule transient animations that keep the tree "not settled".
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile('goldens/feed_article_${c.suffix}.png'),
          );
        });
      });

      testWidgets('VideoCard ${c.suffix}', (tester) async {
        await tester.setDeviceConfig(c.device);

        await mockNetworkImagesFor(() async {
          await tester.pumpWidget(
            goldenTestWrapper(
              device: c.device,
              child: ProviderScope(
                overrides: [
                  youtubePlayerManagerProvider.overrideWith(
                    (ref) => FakeYoutubePlayerManager(),
                  ),
                ],
                child: Scaffold(
                  body: VideoCard(entry: video, isVisible: true),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile('goldens/feed_video_${c.suffix}.png'),
          );
        });
      });
    }
  });
}
