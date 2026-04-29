/// First-launch Terms of Use acceptance gate.
///
/// Shown before [InterestSelectionPage]. The user cannot proceed without
/// tapping "I agree". The link opens https://blips.tech/terms in the
/// system browser.
///
/// Required by App Store Review Guideline 1.2 because the AI chat input
/// is treated as user-generated content.
library;

import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/core/services/external_url_launcher.dart';
import 'package:blips_mobile/features/onboarding/providers/terms_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class TermsAcceptancePage extends ConsumerStatefulWidget {
  const TermsAcceptancePage({super.key});

  static const path = '/terms';
  static const name = 'terms';

  static const termsUrl = 'https://blips.tech/terms';
  static const privacyUrl = 'https://blips.tech/privacy';

  @override
  ConsumerState<TermsAcceptancePage> createState() =>
      _TermsAcceptancePageState();
}

class _TermsAcceptancePageState extends ConsumerState<TermsAcceptancePage> {
  bool _isSubmitting = false;

  Future<void> _handleAccept() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await acceptTerms(ref);
      // Router redirect will fire on the next frame and move us to
      // /interests (or /feed if onboarding is already done).
    } catch (e, stack) {
      logger.warning(
        'Failed to persist Terms acceptance',
        category: LogCategory.app,
        error: e,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t save your acceptance. Please try again.'),
        ),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final ok = await ExternalUrlLauncher.launchUri(Uri.parse(url));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t open $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
              const SizedBox(height: 16),
              Text(
                'Welcome to\nBlips News',
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, end: 0, duration: 400.ms),
              const SizedBox(height: 24),
              Text(
                'A few quick things before you start:',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(height: 24),
              _Bullet(
                icon: Icons.shield_outlined,
                title: 'No tolerance for abuse',
                body:
                    'Don\'t use Blips — including AI chat — to generate or '
                    'distribute hateful, harassing, or otherwise objectionable '
                    'content. Violations end your access.',
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
              const SizedBox(height: 16),
              _Bullet(
                icon: Icons.flag_outlined,
                title: 'Report anything off',
                body:
                    'Every article, video, reel, and AI response has a '
                    'Report option. We review reports within 24 hours.',
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
              const SizedBox(height: 16),
              _Bullet(
                icon: Icons.auto_awesome_outlined,
                title: 'AI can be wrong',
                body:
                    'AI summaries and chat responses may be inaccurate. '
                    'Don\'t rely on them for medical, legal, or financial '
                    'advice.',
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
              const Spacer(),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: () => _openUrl(TermsAcceptancePage.termsUrl),
                    child: const Text('Read full Terms'),
                  ),
                  TextButton(
                    onPressed: () => _openUrl(TermsAcceptancePage.privacyUrl),
                    child: const Text('Privacy Policy'),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _isSubmitting ? null : _handleAccept,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'I agree — continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
              const SizedBox(height: 12),
              Text(
                'By tapping "I agree" you accept the Terms of Use linked above.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 700.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
