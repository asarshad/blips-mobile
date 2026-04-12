import 'package:blips_mobile/features/feed/domain/feed_entry.dart';

class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

class ChatConversation {
  final int articleId;
  final ArticleFeedEntry article;
  final List<ChatMessage> messages;

  const ChatConversation({
    required this.articleId,
    required this.article,
    required this.messages,
  });

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
  DateTime get lastUpdated =>
      lastMessage?.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class ChatResponse {
  final String content;
  final int remainingDaily;
  final int? remainingArticle;
  final String? responseId;
  final bool usedCachedStarterResponse;

  const ChatResponse({
    required this.content,
    required this.remainingDaily,
    this.remainingArticle,
    this.responseId,
    this.usedCachedStarterResponse = false,
  });
}

class ChatQuotaStatus {
  final int remainingDaily;
  final int? remainingArticle;

  const ChatQuotaStatus({
    required this.remainingDaily,
    this.remainingArticle,
  });
}
