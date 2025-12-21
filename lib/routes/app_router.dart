import 'package:blips_mobile/features/chat/presentation/chat_page.dart';
import 'package:blips_mobile/features/feed/presentation/feed_shell_page.dart';
import 'package:blips_mobile/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Centralized GoRouter definition so navigation can hook into Riverpod.
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
      GoRoute(
        path: ChatPage.path,
        name: ChatPage.name,
        pageBuilder: (context, state) => const MaterialPage(
          fullscreenDialog: true,
          child: ChatPage(),
        ),
      ),
      GoRoute(
        path: SettingsPage.path,
        name: SettingsPage.name,
        pageBuilder: (context, state) => const MaterialPage(
          child: SettingsPage(),
        ),
      ),
    ],
  );
});
