import 'package:blips_mobile/features/chat/data/chat_repository.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

final class RecordingChatRepository implements ChatRepository {
  RecordingChatRepository({
    List<ChatConversation> conversations = const [],
    this.remainingDaily = 10,
    this.responseContent = 'This is a sample AI response for testing.',
  }) : _conversations = List<ChatConversation>.from(conversations);

  final List<ChatConversation> _conversations;
  final int remainingDaily;
  final String responseContent;

  final List<int> deletedArticleIds = <int>[];
  final List<({int articleId, String message})> sentMessages =
      <({int articleId, String message})>[];

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
  Future<ChatResponse> sendMessage(int articleId, String message) async {
    sentMessages.add((articleId: articleId, message: message));
    return ChatResponse(
      content: responseContent,
      remainingDaily: remainingDaily - sentMessages.length,
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
