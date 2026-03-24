import 'package:blips_mobile/core/theme/theme.dart';
import 'package:blips_mobile/features/feed/providers/saved_items_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class SavedItemsPage extends HookConsumerWidget {
  const SavedItemsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(savedItemsSegmentProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final segmentWidth =
                    ((constraints.maxWidth - AppSpacing.sm) / 2)
                        .clamp(120.0, double.infinity);
                return SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<SavedItemsSegment>(
                    groupValue: segment,
                    thumbColor: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.8),
                    children: {
                      SavedItemsSegment.articles: SizedBox(
                        width: segmentWidth,
                        child: _SegmentLabel(
                          label: 'Articles',
                          selected: segment == SavedItemsSegment.articles,
                        ),
                      ),
                      SavedItemsSegment.videos: SizedBox(
                        width: segmentWidth,
                        child: _SegmentLabel(
                          label: 'Videos',
                          selected: segment == SavedItemsSegment.videos,
                        ),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value == null) return;
                      ref.read(savedItemsSegmentProvider.notifier).state =
                          value;
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: switch (segment) {
                SavedItemsSegment.articles => const _SavedArticlesList(),
                SavedItemsSegment.videos => const _SavedVideosList(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedArticlesList extends ConsumerWidget {
  const _SavedArticlesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savedArticlesProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _SavedEmptyState(
        icon: Icons.bookmark_outline,
        title: 'Unable to load saved articles',
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _SavedEmptyState(
            icon: Icons.bookmark_outline,
            title: 'No saved articles yet',
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final item = items[index];
            return _SavedItemCard(
              title: item.title,
              source: item.source,
              imageUrl: item.imageUrl,
              publishedAt: item.publishedAt,
              onTap: () => _openSource(item.sourceUrl),
              onRemove: () => ref
                  .read(savedArticlesProvider.notifier)
                  .remove(item.contentId),
            );
          },
        );
      },
    );
  }
}

class _SavedVideosList extends ConsumerWidget {
  const _SavedVideosList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savedVideosProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _SavedEmptyState(
        icon: Icons.bookmark_outline,
        title: 'Unable to load saved videos',
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _SavedEmptyState(
            icon: Icons.bookmark_outline,
            title: 'No saved videos yet',
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final item = items[index];
            return _SavedItemCard(
              title: item.title,
              source: item.source,
              imageUrl: item.thumbnailUrl,
              publishedAt: item.publishedAt,
              onTap: () => _openSource(item.sourceUrl),
              onRemove: () =>
                  ref.read(savedVideosProvider.notifier).remove(item.contentId),
            );
          },
        );
      },
    );
  }
}

class _SavedItemCard extends StatelessWidget {
  const _SavedItemCard({
    required this.title,
    required this.source,
    required this.publishedAt,
    required this.onTap,
    required this.onRemove,
    this.imageUrl,
  });

  final String title;
  final String source;
  final String? imageUrl;
  final DateTime publishedAt;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: theme.cardColor,
      borderRadius: AppRadius.borderMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppSpacing.allMd,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SavedThumbnail(imageUrl: imageUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _formatSavedDate(publishedAt),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.bookmark_rounded,
                  color: colorScheme.primary,
                ),
                tooltip: 'Remove from saved',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedThumbnail extends StatelessWidget {
  const _SavedThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: AppRadius.borderSm,
      child: SizedBox(
        width: 88,
        height: 88,
        child: imageUrl == null || imageUrl!.trim().isEmpty
            ? Container(
                color: colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Icon(
                  Icons.bookmark_outline,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.bookmark_outline,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}

class _SavedEmptyState extends StatelessWidget {
  const _SavedEmptyState({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

String _formatSavedDate(DateTime date) {
  final now = DateTime.now();
  final local = date.toLocal();
  final diff = now.difference(local);
  if (diff.inDays <= 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${local.month}/${local.day}/${local.year}';
}

Future<void> _openSource(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
