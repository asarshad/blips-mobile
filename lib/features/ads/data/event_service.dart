import 'package:blips_mobile/core/error/error.dart';
import 'package:dio/dio.dart';

/// Fire-and-forget analytics event reporter.
///
/// Sends impression / click events to the backend. Failures are silently
/// logged — they must never disrupt the user experience.
class EventService {
  const EventService(this._dio);

  final Dio _dio;

  /// Record that an item was displayed to the user.
  Future<void> recordImpression({
    required String itemType,
    int? contentId,
    String? adId,
    required String surface,
    String? sessionId,
    String? provider,
    String? adUnitId,
    int? slotIndex,
    String? loadStatus,
  }) async {
    _fire('/events/impression', {
      'item_type': itemType,
      if (contentId != null) 'content_id': contentId,
      if (adId != null) 'ad_id': adId,
      'surface': surface,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      if (sessionId != null) 'session_id': sessionId,
      if (provider != null) 'provider': provider,
      if (adUnitId != null) 'ad_unit_id': adUnitId,
      if (slotIndex != null) 'slot_index': slotIndex,
      if (loadStatus != null) 'load_status': loadStatus,
    });
  }

  /// Record that an item was tapped / clicked.
  Future<void> recordClick({
    required String itemType,
    int? contentId,
    String? adId,
    required String surface,
    String? sessionId,
    String? provider,
    String? adUnitId,
    int? slotIndex,
    String? loadStatus,
  }) async {
    _fire('/events/click', {
      'item_type': itemType,
      if (contentId != null) 'content_id': contentId,
      if (adId != null) 'ad_id': adId,
      'surface': surface,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      if (sessionId != null) 'session_id': sessionId,
      if (provider != null) 'provider': provider,
      if (adUnitId != null) 'ad_unit_id': adUnitId,
      if (slotIndex != null) 'slot_index': slotIndex,
      if (loadStatus != null) 'load_status': loadStatus,
    });
  }

  /// Fire-and-forget POST. Never throws.
  void _fire(String path, Map<String, dynamic> body) {
    // ignore: unawaited_futures
    _dio.post<void>(path, data: body).then<void>((_) {}).catchError((Object e) {
      logger.warning(
        'Event send failed ($path)',
        category: LogCategory.network,
        error: e,
      );
    });
  }
}
