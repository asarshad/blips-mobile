import 'package:flutter/material.dart';

enum ArticleImageLayout {
  hero,
  thumbnail,
}

/// Shared article image renderer for feed cards and chat surfaces.
///
/// The data layer keeps `imageUrl` nullable. This widget is the single place
/// that decides how to render missing or failed article images.
class ArticleImage extends StatelessWidget {
  const ArticleImage.hero({
    super.key,
    required this.imageUrl,
    required this.category,
    required this.source,
  })  : width = null,
        height = null,
        layout = ArticleImageLayout.hero;

  const ArticleImage.thumbnail({
    super.key,
    required this.imageUrl,
    required this.category,
    required this.source,
    required this.width,
    required this.height,
  }) : layout = ArticleImageLayout.thumbnail;

  final String? imageUrl;
  final String category;
  final String source;
  final double? width;
  final double? height;
  final ArticleImageLayout layout;

  bool get _isCompact => layout == ArticleImageLayout.thumbnail;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = imageUrl?.trim();
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return _ArticleImagePlaceholder(
        category: category,
        source: source,
        width: width,
        height: height,
        compact: _isCompact,
      );
    }

    return Image.network(
      mediaUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return _ArticleImagePlaceholder(
          category: category,
          source: source,
          width: width,
          height: height,
          compact: _isCompact,
          loading: true,
        );
      },
      errorBuilder: (_, __, ___) => _ArticleImagePlaceholder(
        category: category,
        source: source,
        width: width,
        height: height,
        compact: _isCompact,
      ),
    );
  }
}

class _ArticleImagePlaceholder extends StatelessWidget {
  const _ArticleImagePlaceholder({
    required this.category,
    required this.source,
    required this.width,
    required this.height,
    required this.compact,
    this.loading = false,
  });

  final String category;
  final String source;
  final double? width;
  final double? height;
  final bool compact;
  final bool loading;

  static const _gradients = {
    'artificial intelligence': [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    'ai': [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    'technology': [Color(0xFF1D4ED8), Color(0xFF0369A1)],
    'science': [Color(0xFF0F766E), Color(0xFF0369A1)],
    'business': [Color(0xFF15803D), Color(0xFF0F766E)],
    'finance': [Color(0xFF15803D), Color(0xFF166534)],
    'health': [Color(0xFFBE185D), Color(0xFF9D174D)],
    'politics': [Color(0xFF475569), Color(0xFF1E293B)],
    'sports': [Color(0xFFEA580C), Color(0xFFB45309)],
    'entertainment': [Color(0xFFD97706), Color(0xFFB45309)],
  };

  static const _icons = {
    'artificial intelligence': Icons.smart_toy_outlined,
    'ai': Icons.smart_toy_outlined,
    'technology': Icons.devices_outlined,
    'science': Icons.science_outlined,
    'business': Icons.trending_up_outlined,
    'finance': Icons.attach_money_outlined,
    'health': Icons.favorite_outline,
    'politics': Icons.account_balance_outlined,
    'sports': Icons.sports_outlined,
    'entertainment': Icons.movie_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final key = category.toLowerCase();
    final colors =
        _gradients[key] ?? [const Color(0xFF334155), const Color(0xFF1E293B)];
    final icon = _icons[key] ?? Icons.article_outlined;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          if (!compact)
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                icon,
                size: 160,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          Center(
            child: loading
                ? SizedBox(
                    width: compact ? 20 : 28,
                    height: compact ? 20 : 28,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  )
                : compact
                    ? Icon(
                        icon,
                        size: 22,
                        color: Colors.white70,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 48, color: Colors.white70),
                          const SizedBox(height: 12),
                          Text(
                            category.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
          ),
          if (!compact && !loading)
            Positioned(
              left: 14,
              bottom: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  source,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
