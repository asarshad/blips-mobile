class ChatHistoryDto {
  final int articleId;
  final List<ConversationDto> conversations;

  ChatHistoryDto({required this.articleId, required this.conversations});

  factory ChatHistoryDto.fromJson(Map<String, dynamic> json) {
    return ChatHistoryDto(
      articleId: json['article_id'] as int,
      conversations: (json['conversations'] as List<dynamic>?)
              ?.map((e) => ConversationDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ConversationDto {
  final int id;
  final int articleId;
  final String message;
  final String sender;
  final String timestamp;

  ConversationDto({
    required this.id,
    required this.articleId,
    required this.message,
    required this.sender,
    required this.timestamp,
  });

  factory ConversationDto.fromJson(Map<String, dynamic> json) {
    return ConversationDto(
      id: json['id'] as int,
      articleId: json['article_id'] as int,
      message: json['message'] as String,
      sender: json['sender'] as String,
      timestamp: json['timestamp'] as String,
    );
  }
}
