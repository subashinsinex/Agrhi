class FeedbackItem {
  final String id;
  final String userId;
  final String message;
  final bool isProblem;
  final String createdAt;
  final String? reply;
  final String? status;

  FeedbackItem({
    required this.id,
    required this.userId,
    required this.message,
    required this.isProblem,
    required this.createdAt,
    this.reply,
    this.status,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    return FeedbackItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      message: json['message'] ?? '',
      isProblem: json['isproblem'] ?? false,
      createdAt: json['created_at'] ?? '',
      reply: json['reply'],
      status: json['status'],
    );
  }
}
