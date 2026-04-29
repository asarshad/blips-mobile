import 'package:blips_mobile/features/feed/presentation/feed_shell_page.dart';
import 'package:blips_mobile/features/onboarding/presentation/interest_selection_page.dart';
import 'package:blips_mobile/features/onboarding/presentation/terms_acceptance_page.dart';
import 'package:blips_mobile/features/onboarding/providers/interests_provider.dart';
import 'package:blips_mobile/features/onboarding/providers/terms_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Centralized GoRouter definition so navigation can hook into Riverpod.
///
/// ChatPage and SettingsPage are embedded as tabs inside [FeedShellPage],
/// so they do not need standalone routes.
///
/// First-launch flow (in order):
///   1. [TermsAcceptancePage] — required by App Review Guideline 1.2 for
///      apps with user-generated content (AI chat input).
///   2. [InterestSelectionPage] — picks initial topics.
///   3. [FeedShellPage] — main app.
///
/// Each gate persists a flag in SharedPreferences and the redirect skips
/// gates whose flag is already set.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: TermsAcceptancePage.path,
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
      GoRoute(
        path: TermsAcceptancePage.path,
        name: TermsAcceptancePage.name,
        pageBuilder: (context, state) => const MaterialPage(
          child: TermsAcceptancePage(),
        ),
      ),
    ],
  );
});

/// Bridges Riverpod state changes to GoRouter's [refreshListenable] so the
/// router re-evaluates its [redirect] whenever a gate flag flips.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _termsSub = _ref.listen<AsyncValue<bool>>(
      termsAcceptedProvider,
      (_, __) => notifyListeners(),
    );
    _onboardingSub = _ref.listen<AsyncValue<bool>>(
      onboardingDoneProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<bool>> _termsSub;
  late final ProviderSubscription<AsyncValue<bool>> _onboardingSub;

  @override
  void dispose() {
    _termsSub.close();
    _onboardingSub.close();
    super.dispose();
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final termsAsync = _ref.read(termsAcceptedProvider);
    final onboardingAsync = _ref.read(onboardingDoneProvider);

    // Either gate still loading — don't redirect, stay put.
    if (termsAsync.isLoading || onboardingAsync.isLoading) return null;

    // Terms gate: fail CLOSED on errors so users cannot bypass via a
    // SharedPreferences init failure. Onboarding gate: fail open (preference,
    // not a legal requirement) so a storage error doesn't hard-block the feed.
    final termsAccepted = termsAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );
    final onboardingDone = onboardingAsync.maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );

    final location = state.matchedLocation;
    final onTermsScreen = location == TermsAcceptancePage.path;
    final onInterestsScreen = location == InterestSelectionPage.path;

    // Gate 1: Terms not accepted → force /terms.
    if (!termsAccepted && !onTermsScreen) {
      return TermsAcceptancePage.path;
    }

    // Gate 1 satisfied but user still on /terms → advance.
    if (termsAccepted && onTermsScreen) {
      return onboardingDone
          ? FeedShellPage.path
          : InterestSelectionPage.path;
    }

    // Gate 2: Onboarding not done → force /interests.
    if (termsAccepted && !onboardingDone && !onInterestsScreen) {
      return InterestSelectionPage.path;
    }

    // Gate 2 satisfied but user still on /interests (e.g. hot reload) → feed.
    if (onboardingDone && onInterestsScreen) {
      return FeedShellPage.path;
    }

    return null;
  }
}
