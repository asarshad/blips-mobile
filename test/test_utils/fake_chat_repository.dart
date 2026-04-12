import 'package:blips_mobile/features/chat/data/chat_repository.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

/// Fake [ChatRepository] for integration / widget tests.
///
/// Returns canned data without hitting the network or local database.
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    this.conversations = const [],
    this.remainingDaily = 10,
    this.remainingArticle = 5,
  });

  final List<ChatConversation> conversations;
  final int remainingDaily;
  final int? remainingArticle;

  @override
  Future<List<ChatConversation>> fetchAllChats() async => conversations;

  @override
  Future<ChatConversation> getChat(ArticleFeedEntry article) async {
    return conversations.firstWhere(
      (c) => c.articleId == article.id,
      orElse: () => ChatConversation(
        articleId: article.id,
        article: article,
        messages: [],
      ),
    );
  }

  @override
  Future<int> getRemainingDailyMessages() async => remainingDaily;

  @override
  Future<ChatQuotaStatus> getQuotaStatus(int articleId) async =>
      ChatQuotaStatus(
        remainingDaily: remainingDaily,
        remainingArticle: remainingArticle,
      );

  @override
  Future<ChatResponse> sendMessage(
    int articleId,
    String message, {
    bool starterPrompt = false,
  }) async {
    return ChatResponse(
      content: 'This is a sample AI response for testing.',
      remainingDaily: remainingDaily - 1,
      remainingArticle: remainingArticle,
      responseId: 'resp-test-1',
      usedCachedStarterResponse: starterPrompt,
    );
  }

  @override
  Future<void> deleteChat(int articleId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
