import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/ads/domain/ad_entry.dart';
import 'package:blips_mobile/features/ads/providers/ads_providers.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen feed card for a sponsored ad entry.
///
/// Matches the look of [ArticleCard] via [FeedCardFrame]-style layout:
/// - 35 % hero image / 65 % content
/// - Clearly labelled **"Sponsored"** badge
/// - Tap opens [clickUrl] in external browser and fires a click event
///
/// When ads are disabled (the default) this widget is never built.
class AdCard extends ConsumerWidget {
  const AdCard({super.key, required this.entry});

  final AdFeedEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _handleTap(ref),
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            // ── Hero image (35 %) ──────────────────────────────
            Expanded(
              flex: 35,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _AdMedia(imageUrl: entry.imageUrl),
                  // "Sponsored" badge
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 16,
                    child: _SponsoredBadge(label: entry.label),
                  ),
                ],
              ),
            ),

            // ── Content (65 %) ─────────────────────────────────
            Expanded(
              flex: 65,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sponsor name
                    Text(
                      entry.sponsorName,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title
                    if (entry.title.isNotEmpty)
                      Text(
                        entry.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 12),

                    // Body
                    if (entry.body != null)
                      Expanded(
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.white.withAlpha(0),
                            ],
                            stops: const [0.0, 0.8, 1.0],
                          ).createShader(bounds),
                          blendMode: BlendMode.dstIn,
                          child: Text(
                            entry.body!,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),

                    const Spacer(),

                    // CTA button
                    if (entry.clickUrl != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _handleTap(ref),
                          child: const Text('Learn More'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTap(WidgetRef ref) async {
    // Fire click event (fire-and-forget)
    ref.read(eventServiceProvider).recordClick(
          itemType: 'AD',
          adId: entry.adId,
          surface: entry.placementId,
        );

    // Open external URL
    final url = entry.clickUrl;
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}

// ── Private widgets ────────────────────────────────────────────

class _AdMedia extends StatelessWidget {
  const _AdMedia({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: AppColors.primary.withAlpha(30),
        alignment: Alignment.center,
        child: const Icon(
          Icons.campaign_outlined,
          size: 48,
          color: AppColors.primary,
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade900,
        alignment: Alignment.center,
        child: const Icon(
          Icons.campaign_outlined,
          size: 48,
          color: Colors.white54,
        ),
      ),
    );
  }
}

class _SponsoredBadge extends StatelessWidget {
  const _SponsoredBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
