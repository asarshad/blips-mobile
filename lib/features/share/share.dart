/// Share feature module for Blips.
///
/// Provides off-screen card rendering and sharing for articles, videos,
/// and reels.
///
/// Usage:
/// ```dart
/// import 'package:blips_mobile/features/share/share.dart';
///
/// // Share an article
/// await ShareService.instance.shareArticle(ArticleShareData(...));
///
/// // Share a video
/// await ShareService.instance.shareVideo(VideoShareData(...));
///
/// // Share a reel (URL only)
/// await ShareService.instance.shareReel(ReelShareData(...));
/// ```
library;

export 'share_card.dart' show ShareCard;
export 'share_card_renderer.dart' show ShareCardRenderer;
export 'share_models.dart';
export 'share_service.dart' show ShareService;
