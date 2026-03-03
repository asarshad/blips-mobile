import 'package:blips_mobile/features/feed/presentation/feed_shell_page.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Centralized GoRouter definition so navigation can hook into Riverpod.
///
/// ChatPage and SettingsPage are embedded as tabs inside [FeedShellPage],
/// so they do not need standalone routes.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: FeedShellPage.path,
    routes: [
      GoRoute(
        path: FeedShellPage.path,
        name: FeedShellPage.name,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: FeedShellPage(),
        ),
      ),
    ],
  );
});
