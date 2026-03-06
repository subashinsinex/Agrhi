import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../src/services/api_service.dart';
import 'chat_models.dart';

// Sliding window rate limiter — respects 30 req/min & 14000 req/day free tier
class ChatRateLimiter {
  static const int _maxPerMinute = 28; // 2 buffer below 30
  static const int _maxPerDay = 13500; // 500 buffer below 14000

  final List<DateTime> _minuteWindow = [];
  int _dailyCount = 0;
  String _dailyDate = '';

  // Load persisted daily count from storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    _dailyDate = prefs.getString('chat_daily_date') ?? '';
    _dailyCount = _dailyDate == today
        ? (prefs.getInt('chat_daily_count') ?? 0)
        : 0;
    if (_dailyDate != today) {
      _dailyDate = today;
      await _persist(prefs);
    }
  }

  Future<void> _persist([SharedPreferences? prefs]) async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs.setInt('chat_daily_count', _dailyCount);
    await prefs.setString('chat_daily_date', _dailyDate);
  }

  // Returns null if safe to send, or Duration to wait
  Duration? checkLimit() {
    final now = DateTime.now();
    _minuteWindow.removeWhere((t) => now.difference(t).inSeconds >= 60);

    if (_dailyCount >= _maxPerDay) return const Duration(hours: 24);

    if (_minuteWindow.length >= _maxPerMinute) {
      final oldest = _minuteWindow.first;
      final waitSecs = 60 - now.difference(oldest).inSeconds + 1;
      return Duration(seconds: waitSecs.clamp(1, 60));
    }

    return null;
  }

  // Call this after every successful API request
  Future<void> record() async {
    _minuteWindow.add(DateTime.now());
    _dailyCount++;
    await _persist();
  }

  bool get isDailyLimitHit => _dailyCount >= _maxPerDay;
  int get dailyRemaining => _maxPerDay - _dailyCount;
  int get minuteRemaining => _maxPerMinute - _minuteWindow.length;
}

// Singleton service — handles all chatbot API calls
class ChatService {
  ChatService._();
  static final instance = ChatService._();

  final rateLimiter = ChatRateLimiter();

  Future<void> init() => rateLimiter.init();

  // Fetch all chat sessions for current user
  Future<List<ChatSession>> getSessions() async {
    final r = await ApiService.instance.get(
      '/chatbot/getSessions',
      requiresAuth: true,
    );
    if (!r.isSuccess) return [];
    final data = r.data is List ? r.data as List : [];
    return data.map((j) => ChatSession.fromJson(j)).toList();
  }

  // Create a new session with given title
  Future<ChatSession?> createSession({String title = 'New Chat'}) async {
    final r = await ApiService.instance.post(
      '/chatbot/createSession',
      body: {'title': title},
      requiresAuth: true,
    );
    if (!r.isSuccess) return null;
    return ChatSession.fromJson(r.data);
  }

  // Fetch all messages for a session
  Future<List<ChatMessage>> getMessages(String sessionId) async {
    final r = await ApiService.instance.get(
      '/chatbot/getMessages/$sessionId',
      requiresAuth: true,
    );
    if (!r.isSuccess) return [];
    final data = r.data is List ? r.data as List : [];
    return data.map((j) => ChatMessage.fromJson(j)).toList();
  }

  // Send message to AI — records request for rate limiting
  Future<Map<String, String>> sendMessage(
    String sessionId,
    String message,
  ) async {
    await rateLimiter.record();
    final r = await ApiService.instance.post(
      '/chatbot/chat/$sessionId',
      body: {'message': message},
      requiresAuth: true,
    );
    if (!r.isSuccess) throw Exception('Failed to send message');
    return {
      'reply': r.data['reply']?.toString() ?? '',
      'userMessageId': r.data['userMessageId']?.toString() ?? '',
      'assistantMessageId':
          r.data['assistantMessageId']?.toString() ??
          'ai_${DateTime.now().millisecondsSinceEpoch}',
    };
  }

  // Delete a session by ID
  Future<bool> deleteSession(String sessionId) async {
    final r = await ApiService.instance.delete(
      '/chatbot/deleteSession/$sessionId',
      requiresAuth: true,
    );
    return r.isSuccess;
  }
}
