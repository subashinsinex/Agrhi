import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../utils/colors.dart';
import '../../../screens/shared/custom_app_bar.dart';
import '../../../screens/shared/smart_retranslator.dart';
import 'chat_models.dart';
import 'chat_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  // Session state
  List<ChatSession> _sessions = [];
  bool _isLoadingSessions = false;
  // ignore: unused_field
  String? _profileImagePath;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );


  // Active chat state
  ChatSession? _activeSession;
  List<_ChatEntry> _entries = [];
  bool _isLoadingMessages = false;
  bool get _isRevealing => _revealingIds.isNotEmpty;
  bool _isSending = false;
  String _pendingTempId = '';

  // Typewriter animation tracking
  final Set<String> _revealingIds = {};

  // Rate limit countdown state
  int _rateLimitSeconds = 0;
  String _pendingMessage = '';
  Timer? _countdownTimer;

  // UI controllers
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  // Suggestion chips
  List<(String, String)> _randomChips = [];

  static const _allSuggestions = [
    ('🌾', 'Best crops for Monsoon season'),
    ('🌽', 'Which crops grow best in Tamil Nadu?'),
    ('🌱', 'How to grow paddy in clay soil?'),
    ('🧅', 'Best time to plant onions in South India'),
    ('🍅', 'Tips for high-yield tomato farming'),
    ('🥜', 'Groundnut cultivation guide'),
    ('🌿', 'Intercropping benefits and methods'),
    ('🫘', 'Best pulses for dry land farming'),
    ('🦠', 'How to treat Rice Blast disease'),
    ('🐛', 'Identify common pest symptoms'),
    ('🍂', 'Why are my crop leaves turning yellow?'),
    ('🐜', 'How to control aphids organically'),
    ('🍄', 'Fungal disease prevention in vegetables'),
    ('🐝', 'Whitefly control in chili plants'),
    ('🌾', 'Stem borer management in paddy'),
    ('🦟', 'How to prevent leaf curl virus'),
    ('🌡️', 'Soil testing methods and labs'),
    ('💧', 'Drip irrigation setup guide'),
    ('🪣', 'How to improve sandy soil fertility'),
    ('🧪', 'What does soil pH mean for crops?'),
    ('💦', 'Sprinkler vs drip irrigation'),
    ('🌍', 'How to prevent soil erosion on slopes'),
    ('🌊', 'Rainwater harvesting for small farms'),
    ('⚗️', 'How to check soil moisture levels'),
    ('🌿', 'Organic fertilizer for tomatoes'),
    ('♻️', 'How to make compost at home'),
    ('🐄', 'Benefits of cow dung manure'),
    ('🌱', 'Vermicomposting step by step'),
    ('💊', 'When to apply urea fertilizer?'),
    ('🧴', 'Difference between NPK and DAP'),
    ('🌻', 'Bio-fertilizers for wheat crops'),
    ('🍀', 'Green manure crops and their benefits'),
    ('☀️', 'Best crops for summer in India'),
    ('❄️', 'Winter crop varieties for North India'),
    ('🌧️', 'Flood-resistant crop varieties'),
    ('🌬️', 'How to protect crops from strong winds'),
    ('📅', 'Kharif vs Rabi season crops explained'),
    ('🏛️', 'PM Kisan scheme eligibility'),
    ('📋', 'Fasal Bima Yojana crop insurance'),
    ('💰', 'Government subsidies for drip irrigation'),
    ('🌾', 'Minimum Support Price for paddy 2025'),
    ('📱', 'Best farming apps for Indian farmers'),
  ];

  List<(String, String)> _pickRandomChips() {
    final pool = List<(String, String)>.from(_allSuggestions);
    pool.shuffle(Random());
    return pool.take(6).toList();
  }

  @override
  void initState() {
    super.initState();
    _randomChips = _pickRandomChips();
    _messageController.addListener(() {
      final h = _messageController.text.trim().isNotEmpty;
      if (h != _hasText) setState(() => _hasText = h);
    });
    _focusNode.addListener(() => setState(() {}));
    // Init service (loads daily count) then fetch sessions
    ChatService.instance.init().then((_) => _loadSessions());
    _loadProfileImage();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─── API Methods ─────────────────────────────────────────────────────────

  Future<void> _loadSessions() async {
    setState(() => _isLoadingSessions = true);
    final sessions = await ChatService.instance.getSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoadingSessions = false;
      });
    }
  }

  Future<void> _loadProfileImage() async {
    final localPath = await _storage.read(key: 'profile_image_local_path');
    if (localPath != null && mounted) {
      setState(() => _profileImagePath = localPath);
    }
  }


  Future<void> _createSession({String title = 'New Chat'}) async {
    final session = await ChatService.instance.createSession(title: title);
    if (session == null) {
      _snack('Failed to create chat', error: true);
      return;
    }
    setState(() {
      _sessions.insert(0, session);
      _activeSession = session;
      _entries = [];
    });
  }

  Future<void> _loadMessages(ChatSession session) async {
    if (_activeSession?.sessionId == session.sessionId) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context);
    setState(() {
      _activeSession = session;
      _entries = [];
      _isLoadingMessages = true;
    });
    final msgs = await ChatService.instance.getMessages(session.sessionId);
    if (mounted) {
      setState(() {
        _entries = msgs
            .map((m) => _ChatEntry(message: m, revealed: true))
            .toList();
        _isLoadingMessages = false;
      });
      _scrollToBottom();
    }
  }

  // Entry point for sending — checks rate limit first
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || _isRevealing) return;

    if (_activeSession == null) {
      await _createSession(
        title: text.length > 30 ? '${text.substring(0, 30)}...' : text,
      );
    }

    _messageController.clear();

    // Always add user bubble immediately for responsive UI
    _addUserBubble(text);

    // Check per-minute and per-day limits
    final wait = ChatService.instance.rateLimiter.checkLimit();
    if (wait != null) {
      _handleRateLimit(wait, text);
      return;
    }

    await _doSend(text);
  }

  // Add user message to chat immediately (optimistic UI)
  void _addUserBubble(String text) {
    _pendingTempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _entries.add(
        _ChatEntry(
          message: ChatMessage(
            messageId: _pendingTempId,
            role: 'user',
            content: text,
            createdAt: DateTime.now().toIso8601String(),
          ),
          revealed: true,
        ),
      );
      _isSending = true;
    });
    _scrollToBottom();
  }

  // Handle rate limit — daily shows error, per-minute starts countdown
  void _handleRateLimit(Duration wait, String text) {
    if (ChatService.instance.rateLimiter.isDailyLimitHit) {
      // Daily limit hit — remove bubble and show error
      setState(() {
        _entries.removeWhere((e) => e.message.messageId == _pendingTempId);
        _isSending = false;
      });
      _snack('Daily limit reached. Please try again tomorrow.', error: true);
      return;
    }

    // Per-minute limit — show countdown and auto-retry
    _pendingMessage = text;
    setState(() => _rateLimitSeconds = wait.inSeconds.clamp(1, 60));

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _rateLimitSeconds--);
      if (_rateLimitSeconds <= 0) {
        timer.cancel();
        _doSend(_pendingMessage);
      }
    });
  }

  // Performs the actual API call and updates chat
  Future<void> _doSend(String text) async {
    try {
      final result = await ChatService.instance.sendMessage(
        _activeSession!.sessionId,
        text,
      );

      final aiId = result['assistantMessageId']!;
      final confirmedUserId = result['userMessageId']!.isNotEmpty
          ? result['userMessageId']!
          : _pendingTempId;

      setState(() {
        // Replace temp user bubble with confirmed one
        final idx = _entries.indexWhere(
          (e) => e.message.messageId == _pendingTempId,
        );
        if (idx != -1) {
          _entries[idx] = _ChatEntry(
            message: ChatMessage(
              messageId: confirmedUserId,
              role: 'user',
              content: text,
              createdAt: DateTime.now().toIso8601String(),
            ),
            revealed: true,
          );
        }

        // Add AI reply with typewriter animation
        _entries.add(
          _ChatEntry(
            message: ChatMessage(
              messageId: aiId,
              role: 'assistant',
              content: result['reply']!,
              createdAt: DateTime.now().toIso8601String(),
            ),
            revealed: false,
          ),
        );
        _revealingIds.add(aiId);

        _isSending = false;
        _rateLimitSeconds = 0;
        _pendingMessage = '';
        _pendingTempId = '';
      });
      _scrollToBottom();
      _loadSessions();
    } catch (_) {
      setState(() {
        _entries.removeWhere((e) => e.message.messageId == _pendingTempId);
        _isSending = false;
        _rateLimitSeconds = 0;
        _pendingMessage = '';
        _pendingTempId = '';
      });
      _snack('Failed to send message', error: true);
    }
  }

  Future<void> _deleteSession(ChatSession session) async {
    final ok = await _confirm(
      title: 'Delete Chat?',
      body: '"${session.title}" will be permanently deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    final success = await ChatService.instance.deleteSession(session.sessionId);
    if (success) {
      setState(() {
        _sessions.removeWhere((s) => s.sessionId == session.sessionId);
        if (_activeSession?.sessionId == session.sessionId) {
          _activeSession = null;
          _entries = [];
        }
      });
    } else {
      _snack('Failed to delete chat', error: true);
    }
  }

  void _onRevealComplete(String messageId) {
    setState(() => _revealingIds.remove(messageId));
    _scrollToBottom();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: error ? Colors.red[700] : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: error ? 4 : 2),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: Text(
              body,
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: destructive
                      ? Colors.red[700]
                      : AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _fmtDate(String ds) {
    try {
      final d = DateTime.parse(ds);
      final diff = DateTime.now().difference(d);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundColor,
      appBar: _appBar(),
      drawer: _drawer(),
      body: Column(
        children: [
          Expanded(child: _activeSession == null ? _welcome() : _chatArea()),
          _inputBar(),
        ],
      ),
    );
  }

  // App bar — title shown as-is (no translation, user's own query text)
  PreferredSizeWidget _appBar() {
    return CustomAppBar(
      title: _activeSession?.title ?? 'AI Assistant',
      translateTitle: _activeSession == null,
      showOnlineStatus: true,
      onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
    );
  }

  // ─── Welcome Screen ───────────────────────────────────────────────────────

  Widget _welcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      child: Column(
        children: [
          // Hero banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                SmartReTranslator(
                  text: 'AI Assistant',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                SmartReTranslator(
                  text:
                      'Your AI Companion for farm guidance. Ask about crops, soil, weather & harvests.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB9F6CA),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Suggested questions header
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Suggested questions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B5E20),
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _randomChips = _pickRandomChips()),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryGreen,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 13,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Refresh',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Shuffled suggestion chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _randomChips.map((c) {
              final (emoji, label) = c;
              return GestureDetector(
                onTap: () {
                  _messageController.text = label;
                  _focusNode.requestFocus();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppColors.primaryGreen,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Chat Area ────────────────────────────────────────────────────────────

  Widget _chatArea() {
    if (_isLoadingMessages) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'Say something to start',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      itemCount: _entries.length + (_isSending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _entries.length && _isSending) return _thinkingBubble();
        final entry = _entries[i];
        final msg = entry.message;
        final isUser = msg.role == 'user';
        final isRevealing = _revealingIds.contains(msg.messageId);
        return isUser ? _userBubble(msg) : _aiBubble(msg, animate: isRevealing);
      },
    );
  }

  // ─── User Bubble ──────────────────────────────────────────────────────────

  Widget _userBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                _snack('Copied');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  msg.content,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: _profileImagePath != null
                  ? Image.file(
                      File(_profileImagePath!),
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: AppColors.primaryGreen,
                      ),
                    )
                  : Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: AppColors.primaryGreen,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AI Bubble ────────────────────────────────────────────────────────────

  Widget _aiBubble(ChatMessage msg, {required bool animate}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.smart_toy,
              size: 18,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 5, left: 2),
                  child: Text(
                    'AI Assistant',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B5E20),
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: msg.content));
                    _snack('Copied');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    // Typewriter on new messages, plain text on loaded history
                    child: animate
                        ? _TypewriterText(
                            text: msg.content,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1C1C1C),
                              height: 1.6,
                              letterSpacing: 0.1,
                            ),
                            onComplete: () => _onRevealComplete(msg.messageId),
                            onCharAdded: _scrollToBottom,
                          )
                        : Text(
                            msg.content,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1C1C1C),
                              height: 1.6,
                              letterSpacing: 0.1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Thinking / Countdown Bubble ─────────────────────────────────────────

  Widget _thinkingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.smart_toy,
              size: 18,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 5, left: 2),
                child: Text(
                  'AGRHI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B5E20),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                // Shows countdown when rate limited, otherwise pulsing dots
                child: _rateLimitSeconds > 0
                    ? _RateLimitCountdown(seconds: _rateLimitSeconds)
                    : const _PulsingDots(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Input Bar ────────────────────────────────────────────────────────────

  Widget _inputBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 28,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1A1A1A),
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: _activeSession == null
                      ? 'Ask AGRHI anything...'
                      : 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _hasText && !_isSending && !_isRevealing
                  ? Colors.white
                  : Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
              boxShadow: _hasText && !_isSending
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: IconButton(
              onPressed: _hasText && !_isSending && !_isRevealing ? _sendMessage : null,
              icon: _isSending
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      color: _hasText
                          ? AppColors.primaryGreen
                          : Colors.white.withOpacity(0.5),
                      size: 22,
                    ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Drawer ───────────────────────────────────────────────────────────────

  Widget _drawer() {
    return Drawer(
      backgroundColor: AppColors.backgroundColor,
      child: Column(
        children: [
          Container(
            color: AppColors.primaryGreen,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SmartReTranslator(
                      text: 'Chat History',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withOpacity(0.8),
                          size: 22,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // New Chat button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: SmartReTranslator(
                  text: 'New Chat',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primaryGreen.withOpacity(0.4),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _activeSession = null;
                    _entries = [];
                    _randomChips = _pickRandomChips();
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: _isLoadingSessions
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : _sessions.isEmpty
                ? _emptyHistory()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    itemCount: _sessions.length,
                    itemBuilder: (_, i) => _sessionTile(_sessions[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sessionTile(ChatSession s) {
    final active = _activeSession?.sessionId == s.sessionId;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: active
            ? Border.all(color: AppColors.primaryGreen, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primaryGreen
                : AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            size: 17,
            color: active ? Colors.white : AppColors.primaryGreen,
          ),
        ),
        title: Text(
          s.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: const Color(0xFF1A1A1A),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Text(
          '${s.messageCount} msgs • ${_fmtDate(s.updatedAt)}',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: Colors.red[300],
          ),
          onPressed: () {
            Navigator.pop(context);
            _deleteSession(s);
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        onTap: () => _loadMessages(s),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _emptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 52,
            color: AppColors.primaryGreen.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No chats yet',
            style: TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start a new conversation',
            style: TextStyle(
              color: AppColors.primaryGreen.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Local Chat Entry Model ───────────────────────────────────────────────────

class _ChatEntry {
  final ChatMessage message;
  final bool revealed;
  _ChatEntry({required this.message, required this.revealed});
}

// ─── Rate Limit Countdown Widget ─────────────────────────────────────────────

class _RateLimitCountdown extends StatelessWidget {
  final int seconds;
  const _RateLimitCountdown({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Sending in ${seconds}s...',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Typewriter Text Widget ───────────────────────────────────────────────────

class _TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback? onComplete;
  final VoidCallback? onCharAdded;

  const _TypewriterText({
    required this.text,
    required this.style,
    this.onComplete,
    this.onCharAdded,
  });

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  String _displayed = '';
  int _index = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    if (!mounted || _done) return;
    if (_index >= widget.text.length) {
      _done = true;
      widget.onComplete?.call();
      return;
    }
    final chunk = (_index + 1).clamp(0, widget.text.length);
    Future.delayed(const Duration(milliseconds: 30), () {
      if (!mounted) return;
      setState(() {
        _displayed = widget.text.substring(0, chunk);
        _index = chunk;
      });
      widget.onCharAdded?.call();
      _tick();
    });
  }

  @override
  Widget build(BuildContext context) => Text(_displayed, style: widget.style);
}

// ─── Pulsing Dots Widget ──────────────────────────────────────────────────────

class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _anims = _ctrls
        .map(
          (c) => Tween<double>(
            begin: 0.0,
            end: -7.0,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) _ctrls[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
          child: AnimatedBuilder(
            animation: _anims[i],
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _anims[i].value),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
