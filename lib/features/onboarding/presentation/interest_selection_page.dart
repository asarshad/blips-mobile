/// Interest selection onboarding screen.
///
/// Shown once at first launch. The user picks up to [kMaxSelectedCategories]
/// topics that matter to them. Selection is soft: non-selected topics are
/// never removed from the feed, they're just ranked slightly lower.
library;

import 'package:blips_mobile/features/feed/presentation/feed_shell_page.dart';
import 'package:blips_mobile/features/onboarding/domain/categories.dart';
import 'package:blips_mobile/features/onboarding/presentation/widgets/category_chip.dart';
import 'package:blips_mobile/features/onboarding/providers/interests_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Route path constant — referenced by the router.
class InterestSelectionPage extends ConsumerWidget {
  const InterestSelectionPage({super.key});

  static const path = '/interests';
  static const name = 'interests';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(interestsNotifierProvider);
    final notifier = ref.read(interestsNotifierProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isAndroidUi =
        !kIsWeb && Theme.of(context).platform == TargetPlatform.android;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(
              top: isAndroidUi ? 4 : 8,
              right: isAndroidUi ? 12 : 16,
            ),
            child: TextButton(
              onPressed: () => _handleSkip(context, ref, notifier),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              child: const Text('Skip'),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        Padding(
          padding: EdgeInsets.fromLTRB(
            isAndroidUi ? 20 : 24,
            isAndroidUi ? 10 : 16,
            isAndroidUi ? 20 : 24,
            0,
          ),
          child: Text(
            'What do you\ncare about?',
            style: textTheme.displaySmall?.copyWith(
              fontSize: isAndroidUi ? 22 : null,
              fontWeight: FontWeight.w700,
              height: isAndroidUi ? 1.1 : 1.15,
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms, delay: 100.ms)
              .slideY(begin: 0.15, end: 0, duration: 500.ms, delay: 100.ms),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            isAndroidUi ? 20 : 24,
            isAndroidUi ? 8 : 10,
            isAndroidUi ? 20 : 24,
            0,
          ),
          child: Text(
            'Pick up to $_kMax topics to surface first — '
            'everything else stays in your feed.',
            style: (isAndroidUi ? textTheme.bodyMedium : textTheme.bodyLarge)
                ?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.55),
              height: 1.45,
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms, delay: 200.ms)
            .slideY(begin: 0.1, end: 0, duration: 500.ms, delay: 200.ms),
        SizedBox(height: isAndroidUi ? 20 : 32),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isAndroidUi ? 16 : 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kAllCategories.asMap().entries.map((entry) {
                final index = entry.key;
                final cat = entry.value;
                final isSelected = selected.contains(cat.id);
                final atCapacity = notifier.isAtCapacity(cat.id);

                return ShakeableCategoryChip(
                  key: ValueKey(cat.id),
                  category: cat,
                  isSelected: isSelected,
                  isAtCapacity: atCapacity,
                  onTap: () => notifier.toggle(cat.id),
                )
                    .animate()
                    .fadeIn(
                      duration: 350.ms,
                      delay: Duration(milliseconds: 300 + index * 40),
                    )
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1, 1),
                      duration: 350.ms,
                      delay: Duration(milliseconds: 300 + index * 40),
                    );
              }).toList(),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: isAndroidUi ? 6 : 8,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: selected.isEmpty
                ? const SizedBox.shrink()
                : Text(
                    '${selected.length} of $_kMax selected',
                    key: ValueKey(selected.length),
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: isAndroidUi ? 20 : 24,
            top: isAndroidUi ? 0 : 4,
          ),
          child: FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => _handleSave(context, ref, notifier),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(isAndroidUi ? 48 : 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              selected.isEmpty ? 'Select at least one topic' : 'Get started',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isAndroidUi ? 15 : 16,
              ),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
      ],
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: isAndroidUi
            ? MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1,
                child: content,
              )
            : content,
      ),
    );
  }

  Future<void> _handleSave(
    BuildContext context,
    WidgetRef ref,
    InterestsNotifier notifier,
  ) async {
    await notifier.save();
    // Invalidate so the router redirect re-evaluates with the updated value.
    ref.invalidate(onboardingDoneProvider);
    if (context.mounted) {
      context.go(FeedShellPage.path);
    }
  }

  Future<void> _handleSkip(
    BuildContext context,
    WidgetRef ref,
    InterestsNotifier notifier,
  ) async {
    await notifier.skip();
    // Invalidate so the router redirect re-evaluates with the updated value.
    ref.invalidate(onboardingDoneProvider);
    if (context.mounted) {
      context.go(FeedShellPage.path);
    }
  }
}

const int _kMax = kMaxSelectedCategories;
