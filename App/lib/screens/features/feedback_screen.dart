// lib/src/screens/features/feedback_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../utils/colors.dart';
import '../../utils/storage_helper.dart';
import '../../src/services/language_service.dart';
import '../../src/services/auth_service.dart';
import '../../src/services/connectivity_service.dart';
import '../../utils/constants.dart';

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

// Smart widget for translation that uses cache then re-translates once cache is ready
class SmartReTranslator extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  const SmartReTranslator({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
  });

  @override
  _SmartReTranslatorState createState() => _SmartReTranslatorState();
}

class _SmartReTranslatorState extends State<SmartReTranslator> {
  late LanguageService languageService;
  String displayedText = '';
  bool _cacheLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    languageService = Provider.of<LanguageService>(context);

    _getInitialTranslation();

    if (!languageService.isInitialized) {
      languageService.addListener(() {
        if (languageService.isInitialized && !_cacheLoaded) {
          _cacheLoaded = true;
          _refreshTranslation();
        }
      });
    } else {
      _cacheLoaded = true;
      _refreshTranslation();
    }
  }

  void _getInitialTranslation() async {
    final cacheKey = languageService.currentLocale.languageCode;
    final cached = languageService.translationCache[cacheKey]?[widget.text];
    if (mounted) {
      setState(() {
        displayedText = cached ?? widget.text;
      });
    }
  }

  void _refreshTranslation() async {
    final translation = await languageService.translate(widget.text);
    if (mounted) {
      setState(() {
        displayedText = translation;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      displayedText.isEmpty ? widget.text : displayedText,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StorageHelper _storage = StorageHelper();
  final AuthService _authService = AuthService();
  final ConnectivityService _connectivityService = ConnectivityService();

  // Form state
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController();
  bool _isProblem = false;
  bool _isSubmitting = false;

  // History state
  late Future<List<FeedbackItem>> _futureFeedbackHistory;
  List<FeedbackItem> _feedbackHistory = [];
  bool _hasHistoryError = false;
  bool _isRetryingHistory = false;
  String _historyErrorMessage = 'Please connect to the internet and try again.';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _futureFeedbackHistory = fetchFeedbackHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_hasHistoryError) {
      // Refresh history when switching to history tab
      _fetchFeedbackHistory();
    }
  }

  void _fetchFeedbackHistory() {
    setState(() {
      _futureFeedbackHistory = fetchFeedbackHistory();
    });
  }

  /// Submit feedback to server
  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Check internet connectivity
    final hasInternet = await _connectivityService.hasInternetConnection();

    if (!hasInternet) {
      setState(() {
        _isSubmitting = false;
      });
      _showSnackBar(
        'No internet connection. Please check your network.',
        isError: true,
      );
      return;
    }

    try {
      final accessToken = await _storage.getAccessToken();
      final userId = await _storage.getUserId();

      print(
        '🔍 Submit Feedback - Access Token: ${accessToken != null ? "Found (${accessToken.length} chars)" : "NULL"}',
      );
      print('🔍 Submit Feedback - User ID: ${userId ?? "NULL"}');

      if (accessToken == null || userId == null) {
        throw Exception('Authentication required');
      }

      final url = Uri.parse('${AppConstants.baseUrl}/feedback/addfeedback');

      // Prepare the JSON body
      final requestBody = {
        'user_id': userId,
        'message': _messageController.text.trim(),
        'isproblem': _isProblem,
      };

      // Print the JSON before sending
      print('🔗 Request URL: $url');
      print('📤 Request Body (JSON): ${jsonEncode(requestBody)}');
      print('📤 Breakdown:');
      print('   - user_id: $userId');
      print('   - message: "${_messageController.text.trim()}"');
      print('   - isproblem: $_isProblem');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(requestBody),
      );

      print('📥 Response Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Feedback submitted successfully');
        _showSnackBar('Feedback submitted successfully!', isError: false);

        // Clear form
        _messageController.clear();
        setState(() {
          _isProblem = false;
          _isSubmitting = false;
        });

        // Refresh history
        _fetchFeedbackHistory();
      } else if (response.statusCode == 401) {
        print('⚠️ 401 Unauthorized - attempting to refresh token');
        // Try to refresh token
        await _authService.refreshAccessToken();
        // Retry submission
        await _submitFeedback();
      } else {
        print('❌ Failed with status code: ${response.statusCode}');
        throw Exception('Failed to submit feedback: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error submitting feedback: $e');
      setState(() {
        _isSubmitting = false;
      });
      _showSnackBar(
        'Failed to submit feedback. Please try again.',
        isError: true,
      );
    }
  }

  /// Fetch feedback history from server
  Future<List<FeedbackItem>> fetchFeedbackHistory() async {
    final accessToken = await _storage.getAccessToken();
    final userId = await _storage.getUserId();

    print(
      '🔍 Feedback History - Access Token: ${accessToken != null ? "Found" : "NULL"}',
    );
    print('🔍 User ID: ${userId ?? "NULL"}');

    if (accessToken == null || userId == null) {
      throw Exception('Authentication required');
    }

    try {
      print('🔄 Fetching feedback history for user ID: $userId');
      final url = Uri.parse(
        '${AppConstants.baseUrl}/feedback/getfeedback/$userId',
      );
      print('🔗 Request URL: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('📥 Response Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          _hasHistoryError = false;
        });

        final responseBody = response.body.trim();

        // Handle empty response
        if (responseBody.isEmpty || responseBody == '[]') {
          print('✅ No feedback history found - returning empty list');
          setState(() {
            _feedbackHistory = [];
          });
          return [];
        }

        final dynamic jsonData = jsonDecode(responseBody);

        // Handle both array and object responses
        List<dynamic> data;
        if (jsonData is List) {
          data = jsonData;
        } else if (jsonData is Map && jsonData['data'] != null) {
          data = jsonData['data'] as List;
        } else {
          print('⚠️ Unexpected response format');
          data = [];
        }

        final feedbackList = data
            .map((json) => FeedbackItem.fromJson(json))
            .toList()
            .reversed
            .toList(); // Show newest first

        setState(() {
          _feedbackHistory = feedbackList;
        });

        print('✅ Feedback history loaded: ${feedbackList.length} items');
        return feedbackList;
      } else if (response.statusCode == 404) {
        // 404 could mean no feedback exists OR wrong endpoint
        print('⚠️ 404 Error - endpoint not found or no data');
        print('📥 Response body: ${response.body}');

        // Return empty list instead of throwing error
        setState(() {
          _hasHistoryError = false;
          _feedbackHistory = [];
        });

        return [];
      } else if (response.statusCode == 401) {
        _setHistoryError();
        print('❌ Unauthorized - access token may be invalid or expired');
        throw Exception('Session expired - please log in again');
      } else {
        _setHistoryError();
        print('❌ HTTP Error ${response.statusCode}: ${response.body}');
        throw Exception(
          'Failed to load feedback history: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is FormatException) {
        print('❌ JSON parsing error: $e');
      } else {
        print('❌ Error fetching feedback history: $e');
      }
      _setHistoryError();
      rethrow;
    }
  }

  void _setHistoryError() {
    setState(() {
      _hasHistoryError = true;
    });
  }

  /// Intelligent retry with connectivity check and token refresh
  Future<void> _handleHistoryRetry() async {
    if (_isRetryingHistory) return;

    setState(() {
      _isRetryingHistory = true;
      _historyErrorMessage = 'Checking connection...';
    });

    print('🔄 Retry initiated - checking internet connectivity...');

    // Check internet connectivity
    final hasInternet = await _connectivityService.hasInternetConnection();

    if (!hasInternet) {
      print('❌ No internet connection available');
      setState(() {
        _isRetryingHistory = false;
        _historyErrorMessage =
            'No internet connection. Please check your network and try again.';
      });
      return;
    }

    print('✅ Internet connection available');

    setState(() {
      _historyErrorMessage = 'Refreshing access token...';
    });

    // Try to refresh access token
    try {
      print('🔄 Attempting to refresh access token...');
      await _authService.refreshAccessToken();
      print('✅ Access token refreshed successfully');

      // Reload the history
      setState(() {
        _hasHistoryError = false;
        _isRetryingHistory = false;
        _historyErrorMessage = 'Please connect to the internet and try again.';
      });

      print('🔄 Reloading feedback history...');
      _fetchFeedbackHistory();
    } catch (e) {
      print('❌ Failed to refresh access token: $e');

      final errorMsg = e.toString();
      if (errorMsg.contains('expired') || errorMsg.contains('invalid')) {
        setState(() {
          _isRetryingHistory = false;
          _historyErrorMessage = 'Session expired. Please log in again.';
        });
      } else {
        setState(() {
          _isRetryingHistory = false;
          _historyErrorMessage =
              'Server is unavailable. Please try again later.';
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red[700] : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  /// Get icon based on feedback status
  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'not viewed':
        return Icons.schedule;
      case 'viewed':
        return Icons.visibility;
      case 'responsed':
        return Icons.reply;
      case 'solved':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  /// Get color based on feedback status
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'not viewed':
        return Colors.grey[600]!;
      case 'viewed':
        return Colors.blue[700]!;
      case 'responsed':
        return Colors.orange[700]!;
      case 'solved':
        return Colors.green[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  /// Get display text based on feedback status
  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'not viewed':
        return 'Not Viewed';
      case 'viewed':
        return 'Viewed';
      case 'responsed':
        return 'Responded';
      case 'solved':
        return 'Solved';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: SmartReTranslator(
          text: 'Help & Support',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.textWhite,
        elevation: 8,
        shadowColor: AppColors.shadowColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          tabs: [
            Tab(
              child: SmartReTranslator(
                text: 'Feedback',
                style: const TextStyle(),
              ),
            ),
            Tab(
              child: SmartReTranslator(
                text: 'History',
                style: const TextStyle(),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSendFeedbackTab(), _buildHistoryTab()],
      ),
    );
  }

  Widget _buildSendFeedbackTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              SmartReTranslator(
                text: 'We value your feedback!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              SmartReTranslator(
                text:
                    'Please share your thoughts, suggestions, or report any issues you encounter.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              SmartReTranslator(
                text: 'Your Message',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 8,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Type your feedback here...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.primaryGreen,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your feedback';
                  }
                  if (value.trim().length < 10) {
                    return 'Feedback must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Switch/Slider instead of Checkbox
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isProblem
                            ? Icons.bug_report
                            : Icons.chat_bubble_outline,
                        color: _isProblem
                            ? Colors.red[700]
                            : AppColors.primaryGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SmartReTranslator(
                              text: _isProblem
                                  ? 'Report a Problem'
                                  : 'General Feedback',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _isProblem
                                    ? Colors.red[700]
                                    : AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SmartReTranslator(
                              text: _isProblem
                                  ? 'Toggle off for suggestions'
                                  : 'Toggle on to report a bug',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isProblem,
                        onChanged: (value) {
                          setState(() {
                            _isProblem = value;
                          });
                        },
                        activeColor: Colors.red[700],
                        activeTrackColor: Colors.red[200],
                        inactiveThumbColor: AppColors.primaryGreen,
                        inactiveTrackColor: AppColors.primaryGreen.withOpacity(
                          0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : SmartReTranslator(
                        text: 'Submit Feedback',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_hasHistoryError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRetryingHistory ? Icons.refresh : Icons.wifi_off,
              size: 80,
              color: _isRetryingHistory ? AppColors.primaryGreen : Colors.grey,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SmartReTranslator(
                text: _historyErrorMessage,
                style: TextStyle(
                  color: _isRetryingHistory
                      ? AppColors.primaryGreen
                      : Colors.grey,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: _isRetryingHistory
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: SmartReTranslator(
                text: _isRetryingHistory ? 'Retrying...' : 'Retry',
                style: const TextStyle(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              onPressed: _isRetryingHistory ? null : _handleHistoryRetry,
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<FeedbackItem>>(
      future: _futureFeedbackHistory,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          _setHistoryError();
          return const SizedBox.shrink();
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.feedback_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                SmartReTranslator(
                  text: 'No feedback history yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                SmartReTranslator(
                  text: 'Your submitted feedback will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _feedbackHistory.length,
            itemBuilder: (context, index) {
              final feedback = _feedbackHistory[index];
              return _buildFeedbackHistoryCard(feedback);
            },
          );
        }
      },
    );
  }

  Widget _buildFeedbackHistoryCard(FeedbackItem feedback) {
    return Card(
      key: ValueKey(feedback.id),
      color: Colors.white,
      elevation: 2,
      shadowColor: AppColors.primaryGreen.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: feedback.isProblem
                        ? Colors.red[50]
                        : AppColors.primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        feedback.isProblem
                            ? Icons.bug_report
                            : Icons.chat_bubble_outline,
                        size: 14,
                        color: feedback.isProblem
                            ? Colors.red[700]
                            : AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 4),
                      SmartReTranslator(
                        text: feedback.isProblem ? 'Problem' : 'Feedback',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: feedback.isProblem
                              ? Colors.red[700]
                              : AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SmartReTranslator(
                  text: _formatDate(feedback.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              feedback.message,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            // Show status and reply only if isProblem is true
            if (feedback.isProblem) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge with 4 states
                    Row(
                      children: [
                        Icon(
                          _getStatusIcon(feedback.status),
                          size: 14,
                          color: _getStatusColor(feedback.status),
                        ),
                        const SizedBox(width: 6),
                        SmartReTranslator(
                          text: _getStatusText(feedback.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(feedback.status),
                          ),
                        ),
                      ],
                    ),
                    // Reply if exists
                    if (feedback.reply != null &&
                        feedback.reply!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.reply,
                            size: 14,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              feedback.reply!,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontStyle: FontStyle.italic,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }
}
