import 'package:blips_mobile/core/network/dio_provider.dart';
import 'package:blips_mobile/features/feed/data/starters_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// Re-export for convenience
export 'package:blips_mobile/features/feed/data/starters_repository.dart'
    show ConversationStarters, defaultFallbackStarters;

/// Provides a singleton [StartersRepository].
final startersRepositoryProvider = Provider<StartersRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return StartersRepository(dio);
});

/// Fetches conversation starters for a specific content ID.
///
/// Uses .family to create a separate provider for each content ID.
/// Results are cached by Riverpod until the provider is disposed.
final startersProvider = FutureProvider.family
    .autoDispose<ConversationStarters, int>((ref, contentId) async {
  final repository = ref.watch(startersRepositoryProvider);
  return repository.getStarters(contentId);
});
