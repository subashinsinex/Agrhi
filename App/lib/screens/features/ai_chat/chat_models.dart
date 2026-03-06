class ChatSession {
  final String sessionId;
  final String title;
  final String createdAt;
  final String updatedAt;
  final int messageCount;

  ChatSession({
    required this.sessionId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      sessionId: json['session_id']?.toString() ?? '',
      title: json['title'] ?? 'New Chat',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      messageCount: int.tryParse(json['message_count']?.toString() ?? '0') ?? 0,
    );
  }
}

class ChatMessage {
  final String messageId;
  final String role; // 'user' or 'assistant'
  final String content;
  final String createdAt;

  ChatMessage({
    required this.messageId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id']?.toString() ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
