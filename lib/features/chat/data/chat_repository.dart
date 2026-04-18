import 'package:blips_mobile/core/database/database_helper.dart';
import 'package:blips_mobile/core/diagnostics/app_diagnostics.dart';
import 'package:blips_mobile/core/error/app_logger.dart';
import 'package:blips_mobile/core/error/error.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/feed/data/dto/article_dto.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

class ChatRepository {
  final Dio _dio;
  final ChatLocalStore _db;
  final AppDiagnosticsController? _diagnostics;

  ChatRepository(
    this._dio, {
    ChatLocalStore? localStore,
    AppDiagnosticsController? diagnostics,
  })  : _db = localStore ?? DatabaseHelper.instance,
        _diagnostics = diagnostics;

  Future<List<ChatConversation>> fetchAllChats() async {
    try {
      // 1. Get article IDs from local DB
      final articleIds = await _db.getChatArticleIds();
      logger.debug(
        'fetchAllChats: Found ${articleIds.length} conversations in local DB',
        category: LogCategory.app,
      );

      if (articleIds.isEmpty) return [];

      final conversations = <ChatConversation>[];

      for (final id in articleIds) {
        try {
          // Fetch article details
          logger.debug(
            'Fetching article details for $id',
            category: LogCategory.network,
          );

          Map<String, dynamic>? data;

          if (id < 0) {
            // It's a video
            final videoId = -id;
            final response = await _dio.get<Map<String, dynamic>>(
              '/videos/$videoId',
            );
            if (response.data != null) {
              final v = response.data!;
              data = {
                'id': id, // Keep negative ID
                'title': v['title'],
                'source_url': v['video_url'] ?? v['source_url'] ?? '',
                'summary': v['summary'],
                'image_url': v['thumbnail_url'],
                'published_date': v['published_date'],
                'created_at': v['created_at'],
                'read_time_minutes': (v['duration_seconds'] as int? ?? 0) ~/ 60,
                'tags': <dynamic>[],
              };
            }
          } else {
            final response = await _dio.get<Map<String, dynamic>>(
              '/articles/$id',
            );
            data = response.data;
          }

          if (data == null) {
            logger.debug(
              'Response data is null for $id',
              category: LogCategory.network,
            );
            continue;
          }

          final articleDto = ArticleDto.fromJson(data);
          final article = articleDto.toDomain();

          // Fetch local messages
          final messages = await _db.getMessages(id);
          logger.debug(
            'Found ${messages.length} messages for article $id',
            category: LogCategory.app,
          );

          if (messages.isNotEmpty) {
            conversations.add(ChatConversation(
              articleId: id,
              article: article,
              messages: messages,
            ));
          }
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) {
            logger.debug(
              'Article $id not found (404). Deleting local chat history.',
              category: LogCategory.network,
            );
            await _db.deleteChat(id);
          } else {
            logger.warning(
              'Failed to load chat for article $id',
              category: LogCategory.network,
              error: e,
            );
          }
        } catch (e, stack) {
          logger.warning(
            'Failed to load chat for article $id',
            category: LogCategory.app,
            error: e,
            stackTrace: stack,
          );
          // Skip if article fetch fails
        }
      }

      // Sort by last updated
      conversations.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
      logger.debug(
        'Returning ${conversations.length} conversations',
        category: LogCategory.app,
      );
      return conversations;
    } catch (e, stack) {
      logger.error(
        'fetchAllChats failed completely',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  Future<ChatConversation> getChat(ArticleFeedEntry article) async {
    final messages = await _db.getMessages(article.id);
    return ChatConversation(
      articleId: article.id,
      article: article,
      messages: messages,
    );
  }

  Future<ChatQuotaStatus> getQuotaStatus(int articleId) async {
    try {
      final contentItemId = articleId < 0 ? -articleId : articleId;
      final response = await _dio.get<Map<String, dynamic>>(
        '/usage',
        queryParameters: <String, dynamic>{
          'content_item_id': contentItemId,
        },
      );
      return ChatQuotaStatus(
        remainingDaily:
            response.data?['remaining_daily_messages'] as int? ?? 15,
        remainingArticle: response.data?['remaining_article_messages'] as int?,
      );
    } catch (e, stack) {
      logger.warning(
        'Failed to fetch chat usage',
        category: LogCategory.network,
        error: e,
        stackTrace: stack,
      );
      return const ChatQuotaStatus(
        remainingDaily: 15,
        remainingArticle: null,
      );
    }
  }

  Future<int> getRemainingDailyMessages() async {
    final quota = await getQuotaStatus(0);
    return quota.remainingDaily;
  }

  Future<ChatResponse> sendMessage(
    int articleId,
    String message, {
    bool starterPrompt = false,
  }) async {
    logger.debug('Sending message for article $articleId');
    final lastResponseId = await _db.getLastResponseId(articleId);

    // 1. Save user message locally
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
    );
    await _db.insertMessage(articleId, userMsg);

    // 2. Get history (excluding current message for API call if needed, but API takes history + message)
    // The backend expects 'history' to be previous messages.
    final history = await _db.getMessages(articleId);
    final previousHistory = history.where((m) => m.id != userMsg.id).toList();
    final hasPreviousResponseId =
        lastResponseId != null && lastResponseId.trim().isNotEmpty;
    final span = _diagnostics?.startSpan(
      scope: 'chat',
      action: 'send_message',
      surface: articleId < 0 ? 'videos' : 'articles',
      data: <String, Object?>{
        'articleId': articleId,
        'historyLength': previousHistory.length,
        'hasPreviousResponseId': hasPreviousResponseId,
        'isFollowUp': previousHistory.isNotEmpty,
      },
    );

    // 3. Call API
    try {
      final isVideo = articleId < 0;
      final contentItemId = isVideo ? -articleId : articleId;

      final payload = <String, dynamic>{
        'message': message,
        'sender': 'user',
        'content_item_id': contentItemId,
        'history': previousHistory
            .map((m) => {
                  'role': m.role,
                  'content': m.content,
                })
            .toList(),
        'starter_prompt': starterPrompt,
      };
      if (hasPreviousResponseId) {
        payload['previous_response_id'] = lastResponseId;
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/ai/respond',
        data: payload,
      );

      final aiContent = response.data?['response'] as String;
      final responseId = response.data?['response_id'] as String?;
      final remainingDaily = response.data?['remaining_daily'] as int? ?? 0;
      final remainingArticle = response.data?['remaining_article'] as int?;
      final usedCachedStarterResponse =
          response.data?['used_cached_starter_response'] as bool? ?? false;

      // 4. Save AI response locally
      final aiMsg = ChatMessage(
        id: const Uuid().v4(),
        role: 'assistant',
        content: aiContent,
        timestamp: DateTime.now(),
      );
      await _db.insertMessage(articleId, aiMsg);
      await _db.setLastResponseId(articleId, responseId);
      if (!usedCachedStarterResponse) {
        try {
          await _dio.post<void>(
            '/session/interactions',
            data: {
              'content_item_id': contentItemId,
              'event_type': 'CHAT_MESSAGE',
              'extra_data': {
                'surface': isVideo ? 'videos' : 'articles',
              },
            },
          );
        } catch (e, stack) {
          logger.warning(
            'Failed to record chat message interaction',
            category: LogCategory.network,
            error: e,
            stackTrace: stack,
          );
        }
      }
      logger.debug('AI response saved for article $articleId');
      span?.success(
        data: <String, Object?>{
          'statusCode': response.statusCode,
          'responseIdPresent': responseId != null && responseId.isNotEmpty,
          'remainingDaily': remainingDaily,
          'remainingArticle': remainingArticle,
          'starterPrompt': starterPrompt,
          'usedCachedStarterResponse': usedCachedStarterResponse,
        },
      );

      return ChatResponse(
        content: aiContent,
        remainingDaily: remainingDaily,
        remainingArticle: remainingArticle,
        responseId: responseId,
        usedCachedStarterResponse: usedCachedStarterResponse,
      );
    } catch (e, stack) {
      logger.warning(
        'Chat API call failed',
        category: LogCategory.network,
        error: e,
        stackTrace: stack,
      );
      final detail = e is DioException && e.response?.data is Map
          ? (e.response?.data as Map)['detail']
          : null;
      if (e is DioException && e.response?.statusCode == 429) {
        try {
          await _db.deleteMessage(userMsg.id);
        } catch (deleteError, deleteStack) {
          logger.warning(
            'Failed to remove unsent local message after quota rejection',
            category: LogCategory.app,
            error: deleteError,
            stackTrace: deleteStack,
          );
        }
      }
      span?.failure(
        e,
        stackTrace: e is DioException ? e.stackTrace : null,
        data: <String, Object?>{
          'historyLength': previousHistory.length,
          'hasPreviousResponseId': hasPreviousResponseId,
          'starterPrompt': starterPrompt,
          'statusCode': e is DioException ? e.response?.statusCode : null,
          'serverDetail': detail?.toString(),
        },
      );
      rethrow;
    }
  }

  Future<void> deleteChat(int articleId) async {
    await _db.deleteChat(articleId);
  }
}
