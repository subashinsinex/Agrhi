import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../utils/storage_helper.dart';
import '../../src/services/language_service.dart';
import '../../src/services/auth_service.dart';
import '../../src/services/api_service.dart';
import '../shared/smart_retranslator.dart';
import '../shared/custom_app_bar.dart';

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

class FeedbackScreen extends StatefulWidget {
  final Map<String, dynamic>? shopReference;

  const FeedbackScreen({super.key, this.shopReference});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StorageHelper _storage = StorageHelper();
  final AuthService _authService = AuthService();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController();
  bool _isProblem = false;
  bool _isSubmitting = false;

  Map<String, dynamic>? _currentShopReference;

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

    _currentShopReference = widget.shopReference;

    if (_currentShopReference != null) {
      _isProblem = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadPhrases();
    });
  }

  Future<void> _preloadPhrases() async {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    await languageService.preloadTexts([
      'Help & Support',
      'Feedback',
      'History',
      'We value your feedback!',
      'Help us improve Agrhi! Share your feedback or report any issues you encounter.',
      'Your Message',
      'Type your feedback here...',
      'Please enter your feedback',
      'Feedback must be at least 10 characters',
      'Report a Problem',
      'General Feedback',
      'Toggle off for suggestions',
      'Toggle on to report a bug',
      'Submit Feedback',
      'Feedback submitted successfully!',
      'Failed to submit feedback. Please try again.',
      'No internet connection. Please check your network.',
      'Authentication required',
      'Session expired. Please log in again.',
      'Server is unavailable. Please try again later.',
      'Checking connection...',
      'Refreshing access token...',
      'Please connect to the internet and try again.',
      'Retrying...',
      'Retry',
      'No feedback history yet',
      'Your submitted feedback will appear here',
      'Problem',
      'Not Viewed',
      'Viewed',
      'Responded',
      'Solved',
      'Unknown',
      'Today',
      'Yesterday',
      'days ago',
      'Shop deletion request sent',
      'Admin will review your request',
      'Deleting Shop',
      'Reason must be at least 20 characters',
      'Provide reason for deletion',
      'Request Deletion',
      'Request Edit',
      'Explain why you want to delete this shop...',
      'Explain why you need to edit this shop...',
      'Editing Shop',
      'Submit Request',
      'Shop edit request sent',
      'Explain changes needed',
      'General',
      'Issue',
    ], highPriority: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_hasHistoryError) {
      _fetchFeedbackHistory();
    }
  }

  void _fetchFeedbackHistory() {
    setState(() {
      _futureFeedbackHistory = fetchFeedbackHistory();
    });
  }

  void _removeShopReference() {
    setState(() {
      _currentShopReference = null;
      _messageController.clear();
      _isProblem = false;
    });
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = await _storage.getUserId();

      if (userId == null) {
        throw Exception('Authentication required');
      }

      String finalMessage = _messageController.text.trim();

      if (_currentShopReference != null) {
        final shopName = _currentShopReference!['shop_name'] ?? 'Unknown Shop';
        final retailerId = _currentShopReference!['retailer_id'] ?? '';
        final requestType =
            _currentShopReference!['request_type'] ?? 'delete_shop';

        if (requestType == 'delete_shop') {
          finalMessage =
              'DELETE SHOP REQUEST\n\n'
              'Shop Name: $shopName\n'
              'Shop ID: $retailerId\n\n'
              'Reason:\n$finalMessage';
        } else if (requestType == 'edit_shop') {
          finalMessage =
              'EDIT SHOP REQUEST\n\n'
              'Shop Name: $shopName\n'
              'Shop ID: $retailerId\n\n'
              'Changes Needed:\n$finalMessage';
        }
      }

      final response = await ApiService.instance.post(
        '/feedback/addfeedback',
        body: {
          'user_id': userId,
          'message': finalMessage,
          'isproblem': _isProblem,
        },
        requiresAuth: true,
      );

      if (response.isSuccess) {
        String successMessage = 'Feedback submitted successfully!';
        if (_currentShopReference != null) {
          final requestType = _currentShopReference!['request_type'];
          if (requestType == 'delete_shop') {
            successMessage = 'Shop deletion request sent';
          } else if (requestType == 'edit_shop') {
            successMessage = 'Shop edit request sent';
          }
        }

        _showSnackBar(successMessage, isError: false);

        _messageController.clear();
        setState(() {
          _isProblem = false;
          _isSubmitting = false;
          _currentShopReference = null;
        });

        _fetchFeedbackHistory();

        if (widget.shopReference != null) {
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 401) {
        await _authService.refreshAccessToken();
        await _submitFeedback();
      } else if (response.isOffline) {
        throw Exception('No internet connection. Please check your network.');
      } else {
        throw Exception(
          response.error ?? 'Failed to submit feedback: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      String errorMessage = e.toString();
      if (errorMessage.contains('internet') ||
          errorMessage.contains('network')) {
        errorMessage = 'No internet connection. Please check your network.';
      } else {
        errorMessage = 'Failed to submit feedback. Please try again.';
      }

      _showSnackBar(errorMessage, isError: true);
    }
  }

  Future<List<FeedbackItem>> fetchFeedbackHistory() async {
    final userId = await _storage.getUserId();

    if (userId == null) {
      throw Exception('Authentication required');
    }

    try {
      final response = await ApiService.instance.get(
        '/feedback/getfeedback/$userId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        setState(() {
          _hasHistoryError = false;
        });

        final dynamic jsonData = response.data;

        List<dynamic> data;
        if (jsonData is List) {
          data = jsonData;
        } else if (jsonData is Map && jsonData['data'] != null) {
          data = jsonData['data'] as List;
        } else {
          data = [];
        }

        final feedbackList = data
            .map((json) => FeedbackItem.fromJson(json))
            .toList()
            .reversed
            .toList();

        setState(() {
          _feedbackHistory = feedbackList;
        });

        return feedbackList;
      } else if (response.statusCode == 404) {
        setState(() {
          _hasHistoryError = false;
          _feedbackHistory = [];
        });
        return [];
      } else if (response.statusCode == 401) {
        _setHistoryError();
        throw Exception('Session expired - please log in again');
      } else if (response.isOffline) {
        _setHistoryError();
        throw Exception('No internet connection');
      } else {
        _setHistoryError();
        throw Exception(
          'Failed to load feedback history: ${response.statusCode}',
        );
      }
    } catch (e) {
      _setHistoryError();
      rethrow;
    }
  }

  void _setHistoryError() {
    setState(() {
      _hasHistoryError = true;
    });
  }

  Future<void> _handleHistoryRetry() async {
    if (_isRetryingHistory) return;

    setState(() {
      _isRetryingHistory = true;
      _historyErrorMessage = 'Checking connection...';
    });

    setState(() {
      _historyErrorMessage = 'Refreshing access token...';
    });

    try {
      await _authService.refreshAccessToken();

      setState(() {
        _hasHistoryError = false;
        _isRetryingHistory = false;
        _historyErrorMessage = 'Please connect to the internet and try again.';
      });

      _fetchFeedbackHistory();
    } catch (e) {
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
        content: SmartReTranslator(
          text: message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red[700] : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: 'Help & Support',
        showOnlineStatus: true,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.transparent,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.black,
              indicatorWeight: 4,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black.withOpacity(0.30),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.feedback_outlined, size: 20),
                  child: SmartReTranslator(
                    text: 'Feedback',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Tab(
                  icon: Icon(Icons.history, size: 20),
                  child: SmartReTranslator(
                    text: 'History',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildSendFeedbackTab(), _buildHistoryTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendFeedbackTab() {
    final requestType = _currentShopReference?['request_type'] ?? '';
    final isDeleteRequest = requestType == 'delete_shop';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_currentShopReference != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDeleteRequest
                      ? Colors.red.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDeleteRequest
                        ? Colors.red.shade300
                        : Colors.orange.shade300,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDeleteRequest
                            ? Colors.red.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isDeleteRequest
                            ? Icons.delete_forever
                            : Icons.edit_note,
                        color: isDeleteRequest
                            ? Colors.red.shade700
                            : Colors.orange.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SmartReTranslator(
                            text: isDeleteRequest
                                ? 'Deleting Shop'
                                : 'Editing Shop',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDeleteRequest
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentShopReference!['shop_name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _removeShopReference,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDeleteRequest
                              ? Colors.red.shade100
                              : Colors.orange.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: isDeleteRequest
                              ? Colors.red.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: SmartReTranslator(
                        text: 'Admin will review your request',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF082E1B), Color(0xFF005A2B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmartReTranslator(
                      text: 'We value your feedback!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    SmartReTranslator(
                      text:
                          'Help us improve Agrhi! Share your feedback or report any issues you encounter.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            SmartReTranslator(
              text: _currentShopReference != null
                  ? (isDeleteRequest
                        ? 'Provide reason for deletion'
                        : 'Explain changes needed')
                  : 'Your Message',
              style: const TextStyle(
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
                hintText: _currentShopReference != null
                    ? (isDeleteRequest
                          ? 'Explain why you want to delete this shop...'
                          : 'Explain why you need to edit this shop...')
                    : 'Type your feedback here...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
                errorBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide(color: Colors.red),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your feedback';
                }

                final minLength = _currentShopReference != null ? 20 : 10;

                if (value.trim().length < minLength) {
                  return _currentShopReference != null
                      ? 'Reason must be at least 20 characters'
                      : 'Feedback must be at least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            if (_currentShopReference == null) _buildFeedbackTypeSwitcher(),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitFeedback,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
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
                      text: _currentShopReference != null
                          ? 'Submit Request'
                          : 'Submit Feedback',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackTypeSwitcher() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildTypeOption(
              isSelected: !_isProblem,
              icon: Icons.chat_bubble_outline,
              title: 'General',
              subtitle: 'Share suggestions or thoughts',
              activeColor: AppColors.primaryGreen,
              onTap: () {
                setState(() {
                  _isProblem = false;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTypeOption(
              isSelected: _isProblem,
              icon: Icons.bug_report,
              title: 'Issue',
              subtitle: 'Report a bug or problem',
              activeColor: Colors.red,
              onTap: () {
                setState(() {
                  _isProblem = true;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

Widget _buildTypeOption({
    required bool isSelected,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade200,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: activeColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: SmartReTranslator(
                    text: title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: activeColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SmartReTranslator(
              text: subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_hasHistoryError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isRetryingHistory ? Icons.refresh : Icons.wifi_off,
                size: 80,
                color: _isRetryingHistory
                    ? AppColors.primaryGreen
                    : Colors.grey,
              ),
              const SizedBox(height: 16),
              SmartReTranslator(
                text: _historyErrorMessage,
                style: TextStyle(
                  color: _isRetryingHistory
                      ? AppColors.primaryGreen
                      : Colors.grey,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
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
              return _buildFeedbackHistoryCard(_feedbackHistory[index]);
            },
          );
        }
      },
    );
  }

  Widget _buildFeedbackHistoryCard(FeedbackItem feedback) {
    String displayMessage = feedback.message;

    if (feedback.message.contains('DELETE SHOP REQUEST') ||
        feedback.message.contains('EDIT SHOP REQUEST')) {
      if (feedback.message.contains('Reason:\n')) {
        final reasonIndex = feedback.message.indexOf('Reason:\n');
        displayMessage = feedback.message.substring(reasonIndex + 8).trim();
      } else if (feedback.message.contains('Changes Needed:\n')) {
        final changesIndex = feedback.message.indexOf('Changes Needed:\n');
        displayMessage = feedback.message.substring(changesIndex + 16).trim();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
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
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: feedback.isProblem
                        ? Colors.red.shade50
                        : AppColors.primaryGreen.withOpacity(0.12),
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
              displayMessage,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
            if (feedback.isProblem) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    if (feedback.reply != null &&
                        feedback.reply!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.reply,
                            size: 14,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              feedback.reply!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontStyle: FontStyle.italic,
                                height: 1.35,
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
}
