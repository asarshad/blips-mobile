# Mobile App Structure Guide

## Overview

The mobile app is a Flutter application using Riverpod for state management. It displays tech news articles and short-form video reels in a TikTok-style interface.

## Directory Structure

```
lib/
├── main.dart               # Entry point
├── app.dart                # MaterialApp configuration
├── bootstrap.dart          # Initialization logic
├── core/                   # Shared utilities
│   ├── api/               # HTTP client setup
│   ├── di/                # Dependency injection
│   └── theme/             # App theming
├── features/              # Feature modules
│   ├── feed/              # Main content feed
│   │   ├── data/          # API calls, DTOs
│   │   ├── domain/        # Business entities
│   │   ├── presentation/  # UI widgets
│   │   └── providers/     # Riverpod providers
│   ├── chat/              # AI chat feature
│   │   ├── data/
│   │   ├── domain/
│   │   ├── presentation/
│   │   └── providers/
│   └── settings/          # User preferences
│       ├── data/
│       ├── presentation/
│       └── providers/
└── routes/                # Navigation setup
```

## Feature Module Pattern

Each feature follows a consistent layered architecture:

```
feature/
├── data/                  # External world
│   ├── dto/              # Data Transfer Objects (JSON ↔ Dart)
│   ├── mappers/          # DTO → Domain conversion
│   └── repository.dart   # API calls
├── domain/               # Business logic
│   └── models.dart       # Pure Dart entities
├── presentation/         # UI
│   ├── pages/           # Full-screen widgets
│   └── widgets/         # Reusable components
└── providers/           # State management
    └── providers.dart   # Riverpod providers
```

**Why this structure?**
- **Testable**: Each layer can be tested independently
- **Replaceable**: Can swap API without touching UI
- **Discoverable**: New developers know where to look

---

## Feature Modules Explained

### `/features/feed/` - Main Content Feed

The heart of the app. Displays articles and videos.

#### Data Layer

```
data/
├── dto/
│   ├── article_dto.dart    # JSON parsing for articles
│   └── video_dto.dart      # JSON parsing for videos
├── mappers/
│   └── feed_mappers.dart   # DTO → Domain conversion
└── feed_repository.dart    # API calls
```

**`FeedRepository`** - All feed-related API calls:
```dart
class FeedRepository {
  final Dio _dio;
  
  Future<FeedPageResult<FeedEntry>> fetchArticlesPage() async {
    // Fetches article playlist rows for the Articles surface
  }

  Future<FeedPageResult<FeedEntry>> fetchVideosPage() async {
    // Fetches video playlist rows for the Videos surface
  }
  
  Future<List<ReelFeedEntry>> fetchReels() async {
    // Fetches short videos for reels view
  }
}
```

#### Domain Layer

```
domain/
└── feed_entry.dart         # FeedEntry, ArticleFeedEntry, VideoFeedEntry, ReelFeedEntry
```

**Why separate domain models from DTOs?**
- DTOs match API response (may change)
- Domain models match app needs (stable)
- Decouples API changes from UI

```dart
// DTO (matches API)
class ArticleDto {
  final int id;
  final String title;
  final String? summary;        // Nullable in API
  final String created_at;      // String in API
}

// Domain (matches app needs)
class ArticleFeedEntry {
  final int id;
  final String title;
  final String summary;         // Never null (defaults to "")
  final DateTime publishedAt;   // Proper DateTime
}
```

#### Presentation Layer

```
presentation/
├── feed_page.dart           # Main feed screen
├── article_card.dart        # Article list item
├── video_card.dart          # Video list item
├── article_detail_page.dart # Full article view
├── reels/
│   ├── optimized_reels_page.dart  # TikTok-style view
│   ├── reel_item.dart            # Single reel widget
│   ├── reel_action_button.dart   # Like, share buttons
│   └── video_performance_overlay.dart  # Debug overlay
└── components/
    └── feed_list.dart       # Paginated list widget
```

#### Providers Layer

```
providers/
├── feed_providers.dart      # Feed state providers
├── optimized_video_provider.dart  # Re-exports video manager
└── video/
    ├── video_player_manager.dart  # Player pool management
    ├── pooled_player.dart         # Single pooled player
    ├── youtube_resolver.dart      # YouTube URL → stream URL
    ├── video_config.dart          # Pool configuration
    └── video_metrics.dart         # Performance tracking
```

### `/features/chat/` - AI Chat

Chat with AI about articles.

```
chat/
├── data/
│   └── chat_repository.dart   # POST /chat endpoint
├── domain/
│   └── chat_models.dart       # ChatMessage, ChatSession
├── presentation/
│   └── chat_page.dart         # Chat UI
└── providers/
    └── chat_providers.dart    # Chat state
```

### `/features/settings/` - User Preferences

Category preferences, theme selection, source management.

```
settings/
├── data/
│   └── settings_repository.dart  # Persist to local storage
├── presentation/
│   └── settings_page.dart        # Settings UI
└── providers/
    └── settings_providers.dart   # Preference state
```

---

## Playback Pipeline Explanation

The video playback system is optimized for TikTok-style scrolling. Here's how it works:

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    OptimizedReelsPage                           │
│   (PageView that shows one reel at a time)                      │
└────────────────────────────┬────────────────────────────────────┘
                             │ 
                             │ Uses
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              OptimizedVideoPlayerManager                        │
│   (Manages pool of 5 video players)                             │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  Player Pool                                             │  │
│   │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐              │  │
│   │  │  0  │ │  1  │ │  2  │ │  3  │ │  4  │              │  │
│   │  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘              │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │  URL → Player Mapping                                    │  │
│   │  {                                                       │  │
│   │    "youtube.com/shorts/abc": Player 0,                   │  │
│   │    "youtube.com/shorts/def": Player 1,                   │  │
│   │    ...                                                   │  │
│   │  }                                                       │  │
│   └─────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Uses
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    YoutubePlayerManager                         │
│   (Manages iframe-based YouTube controllers)                    │
│                                                                 │
│   Input:  https://youtube.com/shorts/abc123                     │
│   Output: ready-to-play YoutubePlayerController                 │
│                                                                 │
│   Uses: youtube_player_flutter package                          │
└─────────────────────────────────────────────────────────────────┘
```

### Flow: User Scrolls to New Video

```
1. User swipes up on PageView
        │
        ▼
2. onPageChanged(index: 5) called
        │
        ▼
3. Manager.onPageChanged():
   a. pauseAll() - stop all playing videos
   b. playVideo(urls[5]) - play current
   c. preload(urls[6], urls[7]) - preload next 2
        │
        ▼
4. playVideo() checks:
   - Is URL already in a player? → Play it
   - Not loaded? → assignAndPreparePlayer()
        │
        ▼
5. assignAndPreparePlayer():
   a. Find available player (or recycle oldest)
   b. Extract YouTube video ID from the URL
   c. Create or reuse a YoutubePlayerController
   d. Initialize the controller state
   e. If isVisible && currentActiveUrl → play()
```

### Player States

```dart
enum PlayerState {
  idle,      // Available for reuse
  loading,   // URL being resolved
  ready,     // Initialized, can play
  playing,   // Currently playing
  paused,    // Paused but ready
  error,     // Failed to load
}
```

### Why Player Pooling?

**Without pooling** (naive approach):
```
Scroll to video 1 → Create player → 3000ms load time
Scroll to video 2 → Create player → 3000ms load time
Scroll to video 3 → Create player → 3000ms load time
Memory: 3 players * ~50MB = 150MB+ 💀
```

**With pooling**:
```
App starts → Create 5 players
Scroll to video 1 → Player 0 loads → 3000ms (first time)
Scroll to video 2 → Player 1 loads → 2000ms (preloaded)
Scroll to video 3 → Player 2 loads → 200ms (preloaded) ✨
Scroll to video 6 → Recycle Player 0 → 2000ms
Memory: 5 players max = ~250MB (bounded) ✅
```

### Performance Metrics

The system tracks:
- **Time to first frame**: How long until video shows
- **URL resolution time**: How long youtube_explode takes
- **Controller init time**: How long Flutter takes

Access via `VideoPerformanceOverlay` (debug mode only).

---

## Where to Add New UI Features

### Adding a New Screen

1. **Create the page** in appropriate feature:

```dart
// lib/features/settings/presentation/about_page.dart
class AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('About')),
      body: // ...
    );
  }
}
```

2. **Add route** in `/lib/routes/`:

```dart
GoRoute(
  path: '/about',
  builder: (context, state) => const AboutPage(),
),
```

3. **Navigate** from other screens:

```dart
context.push('/about');
```

### Adding a New Feed Card Type

1. **Create domain model** in `feed_entry.dart`:

```dart
class PodcastFeedEntry extends FeedEntry {
  final String audioUrl;
  final Duration duration;
  // ...
}
```

2. **Create DTO** in `data/dto/`:

```dart
class PodcastDto {
  factory PodcastDto.fromJson(Map<String, dynamic> json) => // ...
  PodcastFeedEntry toDomain() => // ...
}
```

3. **Create card widget** in `presentation/`:

```dart
class PodcastCard extends StatelessWidget {
  final PodcastFeedEntry entry;
  // ...
}
```

4. **Update feed list** to render new type:

```dart
// In feed_list.dart
Widget _buildItem(FeedEntry entry) {
  return entry.when(
    article: (a) => ArticleCard(entry: a),
    video: (v) => VideoCard(entry: v),
    reel: (r) => ReelCard(entry: r),
    podcast: (p) => PodcastCard(entry: p),  // Add this
  );
}
```

### Adding a New Action Button to Reels

1. **Edit** `reel_action_button.dart`:

```dart
class ReelActionButton extends StatelessWidget {
  // Existing: like, share, comment
  // Add new button type
}
```

2. **Add to** `reel_item.dart` in the `_ActionButtons` widget.

### Adding a New Provider

1. **Create provider** in appropriate feature:

```dart
// lib/features/settings/providers/notification_providers.dart
final notificationSettingsProvider = StateNotifierProvider<
  NotificationSettingsNotifier, 
  NotificationSettings
>((ref) => NotificationSettingsNotifier());
```

2. **Use in widget**:

```dart
class SomeWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    return // ...
  }
}
```

---

## Common Patterns

### Fetching Data with Loading/Error States

```dart
// Provider
final articlesProvider = FutureProvider<List<FeedEntry>>((ref) async {
  final repo = ref.read(feedRepositoryProvider);
  return (await repo.fetchArticlesPage()).items;
});

// Widget
class ArticlesPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(articlesProvider);
    
    return feedAsync.when(
      data: (entries) => FeedList(entries: entries),
      loading: () => CircularProgressIndicator(),
      error: (e, st) => ErrorView(message: e.toString()),
    );
  }
}
```

### Pagination

```dart
// Provider with pagination
class ArticlesNotifier extends StateNotifier<AsyncValue<List<FeedEntry>>> {
  int _page = 1;
  
  Future<void> loadMore() async {
    _page++;
    final newItems = (await _repo.fetchArticlesPage(page: _page)).items;
    state = AsyncValue.data([...state.value!, ...newItems]);
  }
}

// Widget
NotificationListener<ScrollNotification>(
  onNotification: (scroll) {
    if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200) {
      ref.read(feedProvider.notifier).loadMore();
    }
    return false;
  },
  child: ListView.builder(/* ... */),
)
```

### Form Validation

```dart
final formKey = GlobalKey<FormState>();

Form(
  key: formKey,
  child: TextFormField(
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Required';
      }
      return null;
    },
  ),
)

// Submit
if (formKey.currentState!.validate()) {
  // Form is valid
}
```

---

## Testing

### Unit Testing Providers

```dart
void main() {
  test('feedProvider fetches and parses data', () async {
    final container = ProviderContainer(overrides: [
      feedRepositoryProvider.overrideWithValue(MockFeedRepository()),
    ]);
    
    final result = await container.read(feedProvider.future);
    expect(result, hasLength(10));
  });
}
```

### Widget Testing

```dart
void main() {
  testWidgets('ArticleCard displays title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArticleCard(
          entry: ArticleFeedEntry(title: 'Test Title', /* ... */),
        ),
      ),
    );
    
    expect(find.text('Test Title'), findsOneWidget);
  });
}
```

### Integration Testing

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('User can scroll through feed', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    // Scroll down
    await tester.drag(find.byType(ListView), Offset(0, -300));
    await tester.pumpAndSettle();
    
    // Verify new items loaded
    expect(find.byType(ArticleCard), findsWidgets);
  });
}
```
