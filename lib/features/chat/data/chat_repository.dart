import 'package:blips_mobile/core/database/database_helper.dart';
import 'package:blips_mobile/features/chat/domain/chat_models.dart';
import 'package:blips_mobile/features/feed/data/dto/article_dto.dart';
import 'package:blips_mobile/features/feed/domain/feed_entry.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

class ChatRepository {
  final Dio _dio;
  final DatabaseHelper _db;

  ChatRepository(this._dio) : _db = DatabaseHelper.instance;

  Future<List<ChatConversation>> fetchAllChats() async {
    try {
      // 1. Get article IDs from local DB
      final articleIds = await _db.getChatArticleIds();
      print('Repo: fetchAllChats - Found ${articleIds.length} conversations in local DB: $articleIds');
      
      if (articleIds.isEmpty) return [];

      final conversations = <ChatConversation>[];
      
      for (final id in articleIds) {
        try {
          // Fetch article details
          print('Repo: Fetching article details for $id');
          final articleResponse = await _dio.get<Map<String, dynamic>>('/articles/$id');
          
          if (articleResponse.data == null) {
            print('Repo: Article response data is null for $id');
            continue;
          }

          final articleDto = ArticleDto.fromJson(articleResponse.data!);
          final article = articleDto.toDomain();
          
          // Fetch local messages
          final messages = await _db.getMessages(id);
          print('Repo: Found ${messages.length} messages for article $id');
          
          if (messages.isNotEmpty) {
            conversations.add(ChatConversation(
              articleId: id,
              article: article,
              messages: messages,
            ));
          }
        } catch (e, stack) {
          print('Repo: Failed to load chat for article $id: $e');
          print(stack);
          // Skip if article fetch fails
        }
      }

      // Sort by last updated
      conversations.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
      print('Repo: Returning ${conversations.length} conversations');
      return conversations;
    } catch (e, stack) {
      print('Repo: fetchAllChats failed completely: $e');
      print(stack);
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

  Future<int> getRemainingDailyMessages() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/usage');
      return response.data?['remaining_daily_messages'] as int? ?? 5;
    } catch (e) {
      print('Repo: Failed to fetch usage: $e');
      return 5; // Default to allow chatting if check fails (e.g. offline)
    }
  }

  Future<ChatResponse> sendMessage(int articleId, String message) async {
    print('Repo: Sending message for article $articleId');
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
    
    // 3. Call API
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/ai/respond',
        data: {
          'article_id': articleId,
          'message': message,
          'sender': 'user',
          'history': previousHistory.map((m) => {
            'role': m.role,
            'content': m.content,
          }).toList(),
        },
      );
      
      final aiContent = response.data?['response'] as String;
      final remainingDaily = response.data?['remaining_daily'] as int? ?? 0;
      
      // 4. Save AI response locally
      final aiMsg = ChatMessage(
        id: const Uuid().v4(),
        role: 'assistant',
        content: aiContent,
        timestamp: DateTime.now(),
      );
      await _db.insertMessage(articleId, aiMsg);
      print('Repo: AI response saved');
      
      return ChatResponse(content: aiContent, remainingDaily: remainingDaily);
    } catch (e) {
      print('Repo: API call failed: $e');
      // We keep the user message in the DB so the conversation is preserved
      // even if the AI fails to respond (e.g. quota exceeded or network error).
      rethrow;
    }
  }

  Future<void> deleteChat(int articleId) async {
    await _db.deleteChat(articleId);
  }
}
