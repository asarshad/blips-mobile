/// Flutter integration test that captures App Store / Play Store screenshots.
///
/// Run with:
/// ```bash
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/screenshot_test.dart \
///   -d <DEVICE_ID>
/// ```
///
/// Screenshots are saved to `store_metadata/screenshots/` by the custom driver.
@Tags(['screenshots'])
library screenshot_test;

import 'package:blips_mobile/app.dart';
import 'package:blips_mobile/core/theme/debug_overlay.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/chat/providers/chat_providers.dart';
import 'package:blips_mobile/features/feed/data/feed_repository.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:blips_mobile/features/feed/providers/feed_providers.dart';
import 'package:blips_mobile/features/feed/providers/video/youtube_player_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';

import '../test/test_utils/fake_backend_api_client.dart';
import '../test/test_utils/fake_chat_repository.dart';
import '../test/test_utils/fake_feed_cache.dart';
import '../test/test_utils/fake_youtube_player_manager.dart';

// ---------------------------------------------------------------------------
// Sample data that looks realistic in screenshots
// ---------------------------------------------------------------------------

const _sampleArticles = [
  {
    'id': 1,
    'title': 'Apple Unveils M5 Pro Chip With Record-Breaking Performance',
    'source_url': 'https://example.com/apple-m5',
    'summary': 'Apple announced its next-generation M5 Pro '
        'chip today, promising 40% faster CPU performance '
        'and 2x GPU throughput compared to M4 Pro.',
    'image_url': 'https://picsum.photos/seed/apple2026/800/400',
    'published_at': '2026-02-28T10:00:00Z',
    'published_date': '2026-02-28',
    'read_time_minutes': 4,
    'tags': [
      {'name': 'Apple'},
      {'name': 'Hardware'},
    ],
    'freshness_tier': 'A',
    'freshness_reason': 'fresh_published',
    'published_age_seconds': 3600,
    'added_age_seconds': 1800,
    'conversation_starters': {
      'starters': [
        'How does M5 compare to Snapdragon X Elite?',
        'What does this mean for MacBook battery life?',
        'Will this affect Intel market share?',
      ],
    },
  },
  {
    'id': 2,
    'title': 'OpenAI Launches GPT-5 With Native Multimodal Reasoning',
    'source_url': 'https://example.com/gpt5',
    'summary': 'GPT-5 brings true multimodal understanding '
        '— simultaneously processing text, images, audio, '
        'and video in a single context window of 1M tokens.',
    'image_url': 'https://picsum.photos/seed/openai2026/800/400',
    'published_at': '2026-02-28T09:30:00Z',
    'published_date': '2026-02-28',
    'read_time_minutes': 6,
    'tags': [
      {'name': 'AI'},
      {'name': 'OpenAI'},
    ],
    'freshness_tier': 'A',
    'freshness_reason': 'fresh_published',
    'published_age_seconds': 5400,
    'added_age_seconds': 3600,
    'conversation_starters': {
      'starters': [
        'What are the key improvements over GPT-4o?',
        'How does the 1M token window work?',
        'Is this available to free users?',
      ],
    },
  },
  {
    'id': 3,
    'title': 'Google DeepMind Achieves AGI Benchmark in Closed Testing',
    'source_url': 'https://example.com/deepmind-agi',
    'summary': 'In a landmark development, Google '
        'DeepMind reports that its latest model has '
        'surpassed the threshold set by leading AGI '
        'benchmarks during internal evaluations.',
    'image_url': 'https://picsum.photos/seed/deepmind2026/800/400',
    'published_at': '2026-02-28T08:15:00Z',
    'published_date': '2026-02-28',
    'read_time_minutes': 5,
    'tags': [
      {'name': 'Google'},
      {'name': 'AGI'},
    ],
    'freshness_tier': 'A',
    'freshness_reason': 'fresh_published',
    'published_age_seconds': 9000,
    'added_age_seconds': 7200,
    'conversation_starters': {
      'starters': [
        'What benchmarks were used to measure AGI?',
        'How does this compare to OpenAI research?',
        'What are the safety implications?',
      ],
    },
  },
  {
    'id': 4,
    'title': 'Tesla Robotaxi Fleet Begins Operating in Austin',
    'source_url': 'https://example.com/tesla-robotaxi',
    'summary': 'Tesla has officially launched its '
        'autonomous Robotaxi service in Austin, Texas, '
        'with a fleet of 500 vehicles offering rides '
        'through the Tesla app.',
    'image_url': 'https://picsum.photos/seed/tesla2026/800/400',
    'published_at': '2026-02-27T22:00:00Z',
    'published_date': '2026-02-27',
    'read_time_minutes': 3,
    'tags': [
      {'name': 'Tesla'},
      {'name': 'Autonomous'},
    ],
    'freshness_tier': 'B',
    'freshness_reason': 'recent',
    'published_age_seconds': 43200,
    'added_age_seconds': 36000,
    'conversation_starters': {
      'starters': [
        'How does this compare to Waymo?',
        'What are the safety statistics so far?',
        'When will it expand to other cities?',
      ],
    },
  },
  {
    'id': 5,
    'title': 'Rust 2.0 Released With First-Class Async and Effect System',
    'source_url': 'https://example.com/rust-2',
    'summary': 'The Rust programming language reaches '
        'a major milestone with version 2.0, introducing '
        'a built-in effect system and first-class '
        'async/await support.',
    'image_url': 'https://picsum.photos/seed/rust2026/800/400',
    'published_at': '2026-02-27T18:00:00Z',
    'published_date': '2026-02-27',
    'read_time_minutes': 7,
    'tags': [
      {'name': 'Rust'},
      {'name': 'Programming'},
    ],
    'freshness_tier': 'B',
    'freshness_reason': 'recent',
    'published_age_seconds': 57600,
    'added_age_seconds': 50400,
    'conversation_starters': {
      'starters': [
        'What breaking changes does Rust 2.0 introduce?',
        'How does the effect system work?',
        'Will existing crates need to be rewritten?',
      ],
    },
  },
];

const _sampleVideos = [
  {
    'id': 101,
    'title': 'MKBHD: The Future of Foldable Phones in 2026',
    'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'source_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'summary': 'Marques Brownlee reviews the latest '
        'foldable devices and predicts which form '
        'factors will dominate this year.',
    'thumbnail_url': 'https://picsum.photos/seed/mkbhd2026/800/450',
    'source': 'MKBHD',
    'category': 'tech',
    'duration_seconds': 780,
    'published_at': '2026-02-28T08:00:00Z',
    'freshness_tier': 'A',
    'freshness_reason': 'fresh_published',
    'published_age_seconds': 7200,
    'added_age_seconds': 3600,
    'conversation_starters': {
      'starters': ['Which foldable did he rank highest?'],
    },
  },
  {
    'id': 102,
    'title': 'Fireship: 10 AI Tools That Changed Everything This Month',
    'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'source_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'summary': 'A rapid-fire overview of the ten most '
        'impactful AI tools released in Feb 2026.',
    'thumbnail_url': 'https://picsum.photos/seed/fireship2026/800/450',
    'source': 'Fireship',
    'category': 'ai',
    'duration_seconds': 420,
    'published_at': '2026-02-27T16:00:00Z',
    'freshness_tier': 'B',
    'freshness_reason': 'recent',
    'published_age_seconds': 64800,
    'added_age_seconds': 57600,
    'conversation_starters': {
      'starters': ['What was tool #1?'],
    },
  },
];

const _sampleReels = [
  {
    'id': 201,
    'title': 'iOS 20 Hidden Feature You Need to Try',
    'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'source_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'summary': 'Quick tip about a hidden iOS 20 feature.',
    'thumbnail_url': 'https://picsum.photos/seed/ios2026/400/700',
    'source': 'TechTips',
    'duration_seconds': 58,
    'published_at': '2026-02-28T07:00:00Z',
    'freshness_tier': 'A',
    'freshness_reason': 'fresh_published',
    'published_age_seconds': 10800,
    'added_age_seconds': 7200,
    'conversation_starters': {
      'starters': ['How do I enable this?'],
    },
  },
  {
    'id': 202,
    'title': 'This VS Code Extension Is a Game Changer',
    'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'source_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    'summary':
        'A quick look at the VS Code extension everyone is talking about.',
    'thumbnail_url': 'https://picsum.photos/seed/vscode2026/400/700',
    'source': 'DevShorts',
    'duration_seconds': 45,
    'published_at': '2026-02-28T06:30:00Z',
    'freshness_tier': 'A',
    'freshness_reason': 'fresh_published',
    'published_age_seconds': 12600,
    'added_age_seconds': 10800,
    'conversation_starters': {
      'starters': ['What is the extension called?'],
    },
  },
];

// ---------------------------------------------------------------------------
// Fake chat data for chat screenshots
// ---------------------------------------------------------------------------

final _chatArticle = ArticleFeedEntry(
  id: 1,
  title: 'Apple Unveils M5 Pro Chip With Record-Breaking Performance',
  summary: 'Apple announced its next-generation M5 Pro '
      'chip today, promising 40% faster CPU performance '
      'and 2x GPU throughput compared to M4 Pro.',
  source: 'The Verge',
  publishedAt: DateTime(2026, 2, 28, 10),
  url: 'https://example.com/apple-m5',
  imageUrl: 'https://picsum.photos/seed/apple2026/800/400',
  category: 'Hardware',
  readTime: 4,
  conversationStarters: [
    'How does M5 compare to Snapdragon X Elite?',
    'What does this mean for MacBook battery life?',
    'Will this affect Intel market share?',
  ],
);

final _chatArticle2 = ArticleFeedEntry(
  id: 2,
  title: 'OpenAI Launches GPT-5 With Native Multimodal Reasoning',
  summary: 'GPT-5 brings true multimodal understanding.',
  source: 'TechCrunch',
  publishedAt: DateTime(2026, 2, 28, 9, 30),
  url: 'https://example.com/gpt5',
  imageUrl: 'https://picsum.photos/seed/openai2026/800/400',
  category: 'AI',
  readTime: 6,
  conversationStarters: [
    'What are the key improvements over GPT-4o?',
  ],
);

final _chatArticle3 = ArticleFeedEntry(
  id: 3,
  title: 'Google DeepMind Achieves AGI Benchmark in Closed Testing',
  summary:
      'DeepMind reports that its latest model surpasses AGI benchmarks.',
  source: 'Ars Technica',
  publishedAt: DateTime(2026, 2, 28, 8, 15),
  url: 'https://example.com/deepmind-agi',
  imageUrl: 'https://picsum.photos/seed/deepmind2026/800/400',
  category: 'AI',
  readTime: 5,
  conversationStarters: [
    'What benchmarks were used to measure AGI?',
  ],
);

final _sampleConversations = [
  ChatConversation(
    articleId: 1,
    article: _chatArticle,
    messages: [
      ChatMessage(
        id: 'u1',
        role: 'user',
        content: 'How does M5 compare to Snapdragon X Elite?',
        timestamp: DateTime(2026, 2, 28, 10, 5),
      ),
      ChatMessage(
        id: 'a1',
        role: 'assistant',
        content:
            'The M5 Pro outperforms the Snapdragon X Elite in single-core '
            'benchmarks by roughly 25%, while the X Elite maintains a slight '
            "edge in sustained multi-threaded workloads. The M5 Pro's GPU "
            'is significantly faster for ML inference tasks.',
        timestamp: DateTime(2026, 2, 28, 10, 5, 30),
      ),
      ChatMessage(
        id: 'u2',
        role: 'user',
        content: 'What about battery life?',
        timestamp: DateTime(2026, 2, 28, 10, 6),
      ),
      ChatMessage(
        id: 'a2',
        role: 'assistant',
        content:
            'Apple claims up to 22 hours of video playback on the 16" '
            'MacBook Pro with M5 Pro — about 2 hours more than M4 Pro. '
            'The efficiency cores are built on a new 2nm process that '
            'significantly reduces idle power consumption.',
        timestamp: DateTime(2026, 2, 28, 10, 6, 30),
      ),
    ],
  ),
  ChatConversation(
    articleId: 2,
    article: _chatArticle2,
    messages: [
      ChatMessage(
        id: 'u3',
        role: 'user',
        content: 'What are the key improvements over GPT-4o?',
        timestamp: DateTime(2026, 2, 28, 9, 35),
      ),
      ChatMessage(
        id: 'a3',
        role: 'assistant',
        content:
            'GPT-5 introduces native multimodal reasoning — it processes '
            'text, images, audio, and video simultaneously rather than '
            'converting between modalities. The 1M token context window '
            'is 8x larger than GPT-4o, and hallucination rates have '
            'dropped by 60% in benchmark testing.',
        timestamp: DateTime(2026, 2, 28, 9, 35, 30),
      ),
    ],
  ),
  ChatConversation(
    articleId: 3,
    article: _chatArticle3,
    messages: [
      ChatMessage(
        id: 'u4',
        role: 'user',
        content: 'What benchmarks were used?',
        timestamp: DateTime(2026, 2, 28, 8, 20),
      ),
      ChatMessage(
        id: 'a4',
        role: 'assistant',
        content:
            'DeepMind used a combination of ARC-AGI, MMLU-Pro, and a new '
            'proprietary benchmark called "Gemini General Intelligence '
            'Suite" that tests cross-domain reasoning and real-world '
            'problem solving.',
        timestamp: DateTime(2026, 2, 28, 8, 20, 30),
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Suppress the debug overlay for clean screenshots
  setUp(() {
    DeviceDebugOverlay.suppress = true;
  });

  tearDown(() {
    DeviceDebugOverlay.suppress = false;
  });

  /// Build the app wrapped in a [ProviderScope] with fake data so we get
  /// a realistic-looking feed without hitting the real backend.
  ProviderScope buildTestApp({
    List<ChatConversation> chatConversations = const [],
  }) {
    final api = FakeBackendApiClient(
      responses: {
        '/articles/recent': const {'articles': _sampleArticles},
        '/videos/recent': const {'videos': _sampleVideos},
        '/videos/reels': const {'videos': _sampleReels},
      },
    );
    final repo = FeedRepository(api);

    final fakeChatRepo = FakeChatRepository(
      conversations: chatConversations,
    );

    return ProviderScope(
      overrides: [
        feedRepositoryProvider.overrideWithValue(repo),
        feedCacheProvider.overrideWithValue(FakeFeedCache()),
        youtubePlayerManagerProvider.overrideWith(
          (ref) => FakeYoutubePlayerManager(),
        ),
        chatListProvider.overrideWith(
          (ref) async => chatConversations,
        ),
        chatRepositoryProvider.overrideWithValue(fakeChatRepo),
      ],
      child: const BlipsApp(),
    );
  }

  /// Takes a screenshot and saves it via the integration test binding.
  Future<void> takeScreenshot(String name) async {
    await binding.takeScreenshot(name);
  }

  /// Pump frames until images have had time to load from the network.
  Future<void> waitForImages(WidgetTester tester) async {
    // First settle to finish navigation/build
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // Pump extra frames to give network images time to load
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    // Final settle
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  // -----------------------------------------------------------------------
  // Screenshot 1: Articles feed (light mode)
  // -----------------------------------------------------------------------
  testWidgets('screenshot_01_articles_feed', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await waitForImages(tester);

    await takeScreenshot('01_articles_feed');
  });

  // -----------------------------------------------------------------------
  // Screenshot 2: Videos tab
  // -----------------------------------------------------------------------
  testWidgets('screenshot_02_videos_tab', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await waitForImages(tester);

    // Tap Videos tab
    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await waitForImages(tester);

    await takeScreenshot('02_videos_tab');
  });

  // -----------------------------------------------------------------------
  // Screenshot 3: Reels tab
  // -----------------------------------------------------------------------
  testWidgets('screenshot_03_reels_tab', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await waitForImages(tester);

    // Tap Reels tab
    await tester.tap(find.byIcon(Icons.movie_filter_outlined));
    await waitForImages(tester);

    await takeScreenshot('03_reels_tab');
  });

  // -----------------------------------------------------------------------
  // Screenshot 4: Conversation starters (floating bubbles on article)
  // -----------------------------------------------------------------------
  testWidgets('screenshot_04_conversation_starters', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await waitForImages(tester);

    // Tap the chat/bolt button on the first article card to show bubbles
    final boltIcons = find.byIcon(Icons.bolt);
    expect(boltIcons, findsWidgets);
    await tester.tap(boltIcons.first);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await takeScreenshot('04_conversation_starters');
  });

  // -----------------------------------------------------------------------
  // Screenshot 5: Chat list with conversations
  // -----------------------------------------------------------------------
  testWidgets('screenshot_05_chat_list', (tester) async {
    await tester.pumpWidget(
      buildTestApp(chatConversations: _sampleConversations),
    );
    await waitForImages(tester);

    // Tap Chat tab
    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await waitForImages(tester);

    await takeScreenshot('05_chat_list');
  });

  // -----------------------------------------------------------------------
  // Screenshot 6: Chat detail with message bubbles
  // -----------------------------------------------------------------------
  testWidgets('screenshot_06_chat_detail', (tester) async {
    await tester.pumpWidget(
      buildTestApp(chatConversations: _sampleConversations),
    );
    await waitForImages(tester);

    // Navigate to Chat tab first
    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await waitForImages(tester);

    // Tap the first conversation to open chat detail
    final firstConvo = find.text(
      'Apple Unveils M5 Pro Chip With Record-Breaking Performance',
    );
    expect(firstConvo, findsWidgets);
    await tester.tap(firstConvo.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await takeScreenshot('06_chat_detail');
  });

  // -----------------------------------------------------------------------
  // Screenshot 7: Settings tab
  // -----------------------------------------------------------------------
  testWidgets('screenshot_07_settings', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Tap Settings tab
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await takeScreenshot('07_settings');
  });

  // -----------------------------------------------------------------------
  // Screenshot 8: Dark mode — articles feed
  // -----------------------------------------------------------------------
  testWidgets('screenshot_08_dark_mode', (tester) async {
    // Override platform brightness to dark
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

    await tester.pumpWidget(buildTestApp());
    await waitForImages(tester);

    await takeScreenshot('08_dark_mode');

    // Reset after test
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  // -----------------------------------------------------------------------
  // Screenshot 9: Dark mode — chat detail
  // -----------------------------------------------------------------------
  testWidgets('screenshot_09_dark_mode_chat', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

    await tester.pumpWidget(
      buildTestApp(chatConversations: _sampleConversations),
    );
    await waitForImages(tester);

    // Navigate to Chat tab
    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await waitForImages(tester);

    // Tap the first conversation
    final firstConvo = find.text(
      'Apple Unveils M5 Pro Chip With Record-Breaking Performance',
    );
    expect(firstConvo, findsWidgets);
    await tester.tap(firstConvo.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await takeScreenshot('09_dark_mode_chat');

    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
}
