import 'package:blips_mobile/features/feed/presentation/feed_shell_page.dart';
import 'package:blips_mobile/features/onboarding/presentation/interest_selection_page.dart';
import 'package:blips_mobile/features/onboarding/providers/interests_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Centralized GoRouter definition so navigation can hook into Riverpod.
///
/// ChatPage and SettingsPage are embedded as tabs inside [FeedShellPage],
/// so they do not need standalone routes.
///
/// On first launch (onboarding not yet done), the router redirects to
/// [InterestSelectionPage]. After the user saves or skips, they are sent
/// to [FeedShellPage] and the redirect no longer fires.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: FeedShellPage.path,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: FeedShellPage.path,
        name: FeedShellPage.name,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: FeedShellPage(),
        ),
      ),
      GoRoute(
        path: InterestSelectionPage.path,
        name: InterestSelectionPage.name,
        pageBuilder: (context, state) => const MaterialPage(
          child: InterestSelectionPage(),
        ),
      ),
    ],
  );
});

/// Bridges Riverpod state changes to GoRouter's [refreshListenable] so the
/// router re-evaluates its [redirect] whenever [onboardingDoneProvider] settles.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _sub = _ref.listen<AsyncValue<bool>>(
      onboardingDoneProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<bool>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final onboardingAsync = _ref.read(onboardingDoneProvider);

    return onboardingAsync.when(
      // Still loading — don't redirect; stay on current location.
      loading: () => null,
      // On error, fail open: skip onboarding to avoid a blocking screen.
      error: (_, __) => null,
      data: (done) {
        final onInterestsScreen =
            state.matchedLocation == InterestSelectionPage.path;

        // Already completed onboarding but still on the interests screen
        // (e.g. hot-reload during dev): send to feed.
        if (done && onInterestsScreen) return FeedShellPage.path;

        // First launch — steer to interest selection.
        if (!done && !onInterestsScreen) return InterestSelectionPage.path;

        // No redirect needed.
        return null;
      },
    );
  }
}
