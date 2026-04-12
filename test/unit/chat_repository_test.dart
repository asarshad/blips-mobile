@Tags(['unit'])
library chat_repository_test;

import 'package:blips_mobile/core/database/database_helper.dart';
import 'package:blips_mobile/features/chat/data/chat_repository.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChatLocalStore implements ChatLocalStore {
  final Map<int, List<ChatMessage>> messages = <int, List<ChatMessage>>{};
  final Map<int, String?> responseIds = <int, String?>{};

  @override
  Future<void> deleteAllChats() async {
    messages.clear();
    responseIds.clear();
  }

  @override
  Future<void> deleteChat(int articleId) async {
    messages.remove(articleId);
    responseIds.remove(articleId);
  }

  @override
  Future<void> deleteMessage(String id) async {
    for (final entry in messages.values) {
      entry.removeWhere((message) => message.id == id);
    }
  }

  @override
  Future<List<int>> getChatArticleIds() async => messages.keys.toList();

  @override
  Future<String?> getLastResponseId(int articleId) async =>
      responseIds[articleId];

  @override
  Future<List<ChatMessage>> getMessages(int articleId) async =>
      List<ChatMessage>.from(messages[articleId] ?? const <ChatMessage>[]);

  @override
  Future<void> insertMessage(int articleId, ChatMessage message) async {
    messages.putIfAbsent(articleId, () => <ChatMessage>[]).add(message);
  }

  @override
  Future<void> setLastResponseId(int articleId, String? responseId) async {
    responseIds[articleId] = responseId;
  }
}

void main() {
  test('sendMessage persists and reuses previous_response_id across follow-ups',
      () async {
    final store = _FakeChatLocalStore();
    final requests = <Map<String, dynamic>>[];
    final interactionRequests = <Map<String, dynamic>>[];
    final requestOrder = <String>[];
    var responseCount = 0;

    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST' &&
              options.path == '/session/interactions') {
            requestOrder.add(options.path);
            interactionRequests
                .add(Map<String, dynamic>.from(options.data! as Map));
            handler.resolve(
              Response<void>(
                requestOptions: options,
                statusCode: 200,
              ),
            );
            return;
          }

          if (options.method == 'POST' && options.path == '/ai/respond') {
            requestOrder.add(options.path);
            requests.add(Map<String, dynamic>.from(options.data! as Map));
            responseCount += 1;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'response': 'answer-$responseCount',
                  'response_id': 'resp-$responseCount',
                  'remaining_daily': 5 - responseCount,
                },
              ),
            );
            return;
          }

          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Unexpected request',
            ),
          );
        },
      ),
    );

    final repository = ChatRepository(dio, localStore: store);

    final first = await repository.sendMessage(1, 'Tell me more');
    final second = await repository.sendMessage(1, 'What else?');
    await repository.deleteChat(1);

    expect(first.responseId, 'resp-1');
    expect(second.responseId, 'resp-2');
    expect(requests, hasLength(2));
    expect(requests.first['starter_prompt'], isFalse);
    expect(requests.first.containsKey('previous_response_id'), isFalse);
    expect(requests.first['history'], isEmpty);
    expect(requests.last['starter_prompt'], isFalse);
    expect(requests.last['previous_response_id'], 'resp-1');
    expect((requests.last['history'] as List<dynamic>), hasLength(2));
    expect(interactionRequests, hasLength(2));
    expect(requestOrder, [
      '/ai/respond',
      '/session/interactions',
      '/ai/respond',
      '/session/interactions',
    ]);
    expect(store.responseIds.containsKey(1), isFalse);
  });

  test(
      'sendMessage includes starter_prompt and removes unsent local message on quota errors',
      () async {
    final store = _FakeChatLocalStore();
    var interactionCount = 0;

    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST' &&
              options.path == '/session/interactions') {
            interactionCount += 1;
            handler.resolve(
              Response<void>(
                requestOptions: options,
                statusCode: 200,
              ),
            );
            return;
          }

          if (options.method == 'POST' && options.path == '/ai/respond') {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 429,
                  data: <String, dynamic>{
                    'detail': 'Article message quota exceeded',
                    'quota_type': 'article',
                    'message': 'Article message quota exceeded',
                  },
                ),
                type: DioExceptionType.badResponse,
              ),
            );
            return;
          }

          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Unexpected request',
            ),
          );
        },
      ),
    );

    final repository = ChatRepository(dio, localStore: store);

    await expectLater(
      repository.sendMessage(1, 'What are the key takeaways?',
          starterPrompt: true),
      throwsA(isA<DioException>()),
    );

    expect(await store.getMessages(1), isEmpty);
    expect(interactionCount, 0);
  });

  test(
      'cached starter responses skip interaction logging and follow-ups replay without previous_response_id',
      () async {
    final store = _FakeChatLocalStore();
    final requests = <Map<String, dynamic>>[];
    var interactionCount = 0;
    var responseCount = 0;

    final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'POST' &&
              options.path == '/session/interactions') {
            interactionCount += 1;
            handler.resolve(
              Response<void>(
                requestOptions: options,
                statusCode: 200,
              ),
            );
            return;
          }

          if (options.method == 'POST' && options.path == '/ai/respond') {
            requests.add(Map<String, dynamic>.from(options.data! as Map));
            responseCount += 1;
            final data = responseCount == 1
                ? <String, dynamic>{
                    'response': 'cached starter answer',
                    'response_id': null,
                    'remaining_daily': 15,
                    'remaining_article': 5,
                    'used_cached_starter_response': true,
                  }
                : <String, dynamic>{
                    'response': 'follow-up answer',
                    'response_id': 'resp-2',
                    'remaining_daily': 14,
                    'remaining_article': 4,
                    'used_cached_starter_response': false,
                  };
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: data,
              ),
            );
            return;
          }

          handler.reject(
            DioException(
              requestOptions: options,
              error: 'Unexpected request',
            ),
          );
        },
      ),
    );

    final repository = ChatRepository(dio, localStore: store);

    final first = await repository.sendMessage(
      1,
      'What are the key takeaways?',
      starterPrompt: true,
    );
    final second = await repository.sendMessage(1, 'what else?');

    expect(first.responseId, isNull);
    expect(first.usedCachedStarterResponse, isTrue);
    expect(second.responseId, 'resp-2');
    expect(requests, hasLength(2));
    expect(requests.first['starter_prompt'], isTrue);
    expect(requests.first.containsKey('previous_response_id'), isFalse);
    expect(requests.last['starter_prompt'], isFalse);
    expect(requests.last.containsKey('previous_response_id'), isFalse);
    expect((requests.last['history'] as List<dynamic>), hasLength(2));
    expect(interactionCount, 1);
  });
}
