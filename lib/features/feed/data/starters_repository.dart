import 'package:blips_mobile/core/error/error.dart';
import 'package:dio/dio.dart';

/// Data model for conversation starters from the API.
class ConversationStarters {
  const ConversationStarters({
    required this.contentId,
    required this.starters,
    required this.fallback,
  });

  final int contentId;
  final List<String> starters;
  final List<String> fallback;

  /// Creates from API JSON response.
  factory ConversationStarters.fromJson(Map<String, dynamic> json) {
    return ConversationStarters(
      contentId: json['content_id'] as int,
      starters: (json['starters'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      fallback: (json['fallback'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  /// Get all questions (starters + fallback).
  List<String> get allQuestions => [...starters, ...fallback];
}

/// Default fallback starters used when API fails or content ID is invalid.
const defaultFallbackStarters = ConversationStarters(
  contentId: 0,
  starters: [
    'What are the main points of this?',
    'Can you summarize this for me?',
    "What's your opinion on this topic?",
  ],
  fallback: [
    'What should I know about this?',
  ],
);

/// Repository for fetching conversation starters from the API.
class StartersRepository {
  StartersRepository(this._dio);

  final Dio _dio;

  /// Fetch starters for a content item.
  /// 
  /// Returns [defaultFallbackStarters] if the request fails or
  /// if [contentId] is invalid (e.g., negative for videos before
  /// backend video support).
  Future<ConversationStarters> getStarters(int contentId) async {
    // Skip API call for invalid content IDs
    if (contentId <= 0) {
      logger.debug(
        'Invalid contentId $contentId, using fallback starters',
        category: LogCategory.network,
      );
      return defaultFallbackStarters;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/starters/$contentId',
      );

      if (response.data == null) {
        logger.warning(
          'Starters API returned null for contentId=$contentId',
          category: LogCategory.network,
        );
        return defaultFallbackStarters;
      }

      final starters = ConversationStarters.fromJson(response.data!);
      logger.debug(
        'Fetched ${starters.starters.length} starters for contentId=$contentId',
        category: LogCategory.network,
      );
      return starters;
    } on DioException catch (e) {
      // Log but don't crash - fallback gracefully
      logger.warning(
        'Failed to fetch starters for contentId=$contentId: ${e.message}',
        category: LogCategory.network,
      );
      return defaultFallbackStarters;
    } catch (e) {
      logger.error(
        'Unexpected error fetching starters: $e',
        category: LogCategory.network,
      );
      return defaultFallbackStarters;
    }
  }
}
