import 'package:blips_mobile/features/feed/data/feed_session_store.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The single feed surface that should perform a cold-launch blocking fetch.
///
/// Set once after startup tab resolution, then cleared after the initial
/// visible surface has attempted its cold fetch.
final coldLaunchInitialSurfaceProvider =
    StateProvider<FeedSurface?>((_) => FeedSurface.articles);

/// Timestamp of the latest freshness hint for a given feed surface.
final feedDirtyAtProvider =
    StateProvider.family<DateTime?, FeedSurface>((_, __) => null);
