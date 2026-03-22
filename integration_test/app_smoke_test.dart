@Tags(['integration'])
library app_smoke_test;

import 'package:blips_mobile/app.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:blips_mobile/features/onboarding/providers/interests_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';

import '../test/test_utils/fake_backend_api_client.dart';
import '../test/test_utils/fake_feed_cache.dart';
import '../test/test_utils/fake_youtube_player_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  ProviderScope buildTestScope() {
    final api = FakeBackendApiClient(
      responses: {
        '/session/playlist': const {
          'items': <Map<String, dynamic>>[],
          'has_more': false,
          'inventory_state': 'warming_up',
        },
        '/videos/reels': const {
          'videos': <Map<String, dynamic>>[],
        },
      },
    );
    final repo = FeedRepository(api);

    return ProviderScope(
      overrides: [
        // Onboarding already done so the router skips InterestSelectionPage
        // and lands on FeedShellPage (the bottom-nav shell).
        onboardingDoneProvider.overrideWith((ref) async => true),
        feedRepositoryProvider.overrideWithValue(repo),
        feedCacheProvider.overrideWithValue(FakeFeedCache()),
        youtubePlayerManagerProvider.overrideWith(
          (ref) => FakeYoutubePlayerManager(),
        ),
        chatListProvider.overrideWith((ref) async => const []),
      ],
      child: const BlipsApp(),
    );
  }

  testWidgets('launches and shows bottom nav', (tester) async {
    await tester.pumpWidget(buildTestScope());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Bottom nav is icon-only (labels are not rendered).
    expect(find.byIcon(Icons.article), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.movie_filter_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('navigates to Chat tab', (tester) async {
    await tester.pumpWidget(buildTestScope());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Your Conversations'), findsOneWidget);
    expect(find.text('No conversations yet.'), findsOneWidget);
  });

  testWidgets('navigates to Settings tab', (tester) async {
    await tester.pumpWidget(buildTestScope());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Settings'), findsWidgets);
  });
}
