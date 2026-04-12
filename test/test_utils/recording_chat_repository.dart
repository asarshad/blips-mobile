import 'package:blips_mobile/features/chat/data/chat_repository.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

final class RecordingChatRepository implements ChatRepository {
  RecordingChatRepository({
    List<ChatConversation> conversations = const [],
    this.remainingDaily = 10,
    this.remainingArticle = 5,
    this.responseContent = 'This is a sample AI response for testing.',
    this.responseId = 'resp-test-1',
    this.usedCachedStarterResponse = false,
  }) : _conversations = List<ChatConversation>.from(conversations);

  final List<ChatConversation> _conversations;
  final int remainingDaily;
  final int? remainingArticle;
  final String responseContent;
  final String? responseId;
  final bool usedCachedStarterResponse;

  final List<int> deletedArticleIds = <int>[];
  final List<({int articleId, String message, bool starterPrompt})>
      sentMessages = <({int articleId, String message, bool starterPrompt})>[];

  @override
  Future<List<ChatConversation>> fetchAllChats() async =>
      List<ChatConversation>.from(_conversations);

  @override
  Future<ChatConversation> getChat(ArticleFeedEntry article) async {
    return _conversations.firstWhere(
      (conversation) => conversation.articleId == article.id,
      orElse: () => ChatConversation(
        articleId: article.id,
        article: article,
        messages: const <ChatMessage>[],
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
    sentMessages.add(
      (
        articleId: articleId,
        message: message,
        starterPrompt: starterPrompt,
      ),
    );
    return ChatResponse(
      content: responseContent,
      remainingDaily: remainingDaily - sentMessages.length,
      remainingArticle: remainingArticle,
      responseId: responseId,
      usedCachedStarterResponse: usedCachedStarterResponse,
    );
  }

  @override
  Future<void> deleteChat(int articleId) async {
    deletedArticleIds.add(articleId);
    _conversations.removeWhere(
      (conversation) => conversation.articleId == articleId,
    );
  }
}
