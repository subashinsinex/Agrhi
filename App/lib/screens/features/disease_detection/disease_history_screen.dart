import 'dart:io';
import 'package:flutter/material.dart';
import '../../../utils/colors.dart';
import '../../../src/database/database_helper.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/disclaimer_banner.dart';
import '../../../utils/storage_helper.dart';
import '../../shared/smart_retranslator.dart';
import '../../../src/services/sync_service.dart';

class DiseaseHistoryItem {
  final String id;
  final String? imageId;
  final String plantName;
  final String diseaseName;
  final String severity;
  final double confidence;
  final String localPath;
  final String? serverImageUrl;
  final String createdAt;
  final List<String> remedies;
  final List<String> preventions;

  DiseaseHistoryItem({
    required this.id,
    this.imageId,
    required this.plantName,
    required this.diseaseName,
    required this.severity,
    required this.confidence,
    required this.localPath,
    this.serverImageUrl,
    required this.createdAt,
    required this.remedies,
    required this.preventions,
  });

  factory DiseaseHistoryItem.fromJson(Map<String, dynamic> json) {
    final remediesStr = json['remedies'] as String?;
    final preventionsStr = json['preventions'] as String?;

    final remedies = remediesStr != null && remediesStr.isNotEmpty
        ? remediesStr.split('|||').where((s) => s.trim().isNotEmpty).toList()
        : <String>[];

    final preventions = preventionsStr != null && preventionsStr.isNotEmpty
        ? preventionsStr.split('|||').where((s) => s.trim().isNotEmpty).toList()
        : <String>[];

    return DiseaseHistoryItem(
      id: json['id']?.toString() ?? '',
      imageId: json['image_id']?.toString(),
      plantName: json['plant_name']?.toString() ?? 'Unknown Plant',
      diseaseName: json['disease_name']?.toString() ?? 'Unknown Disease',
      severity: json['severity']?.toString() ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      localPath: json['local_path']?.toString() ?? '',
      serverImageUrl: json['server_image_url']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      remedies: remedies,
      preventions: preventions,
    );
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  Color get severityColor {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
      case 'moderate':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String? get imagePath {
    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      return localPath;
    }
    return null;
  }

  String get formattedDate {
    try {
      final date = DateTime.parse(createdAt);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return createdAt;
    }
  }
}

class DiseaseHistoryScreen extends StatefulWidget {
  const DiseaseHistoryScreen({super.key});

  @override
  State<DiseaseHistoryScreen> createState() => _DiseaseHistoryScreenState();
}

class _DiseaseHistoryScreenState extends State<DiseaseHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final StorageHelper _storage = StorageHelper();
  final SyncService _syncService = SyncService.instance;

  final List<DiseaseHistoryItem> _allHistory = [];
  List<DiseaseHistoryItem> _filteredHistory = [];

  static const int _initialPageSize = 10;
  static const int _nextPageSize = 10;

  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;
  bool _showScrollToTop = false;
  bool _isRefreshingAfterImageDownload = false;

  String _errorMessage = 'Failed to load disease history';

  @override
  void initState() {
    super.initState();
    _loadInitialHistory();
    _searchController.addListener(_filterHistory);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 200 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (_scrollController.offset <= 200 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }

    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isInitialLoading &&
        _hasMore &&
        _searchController.text.trim().isEmpty) {
      _loadMoreHistory();
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadInitialHistory() async {
    if (!mounted) return;

    setState(() {
      _isInitialLoading = true;
      _hasError = false;
      _errorMessage = 'Failed to load disease history';
    });

    try {
      final userId = await _storage.getUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final analyses = await _db.getUserAnalysesPaginated(
        userId,
        limit: _initialPageSize,
        offset: 0,
      );

      final historyItems = analyses
          .map((json) => DiseaseHistoryItem.fromJson(json))
          .toList();

      if (!mounted) return;

      setState(() {
        _allHistory
          ..clear()
          ..addAll(historyItems);
        _filteredHistory = List.of(_allHistory);
        _hasMore = historyItems.length == _initialPageSize;
        _hasError = false;
      });

      await _downloadImagesForItems(historyItems);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load disease history: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final userId = await _storage.getUserId();
      if (userId == null) return;

      final analyses = await _db.getUserAnalysesPaginated(
        userId,
        limit: _nextPageSize,
        offset: _allHistory.length,
      );

      final newItems = analyses
          .map((json) => DiseaseHistoryItem.fromJson(json))
          .toList();

      if (!mounted) return;

      setState(() {
        _allHistory.addAll(newItems);
        _applyFilter();
        _hasMore = newItems.length == _nextPageSize;
      });

      await _downloadImagesForItems(newItems);
    } catch (e) {
      debugPrint('❌ Error loading more history: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _filterHistory() {
    if (!mounted) return;
    setState(_applyFilter);
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      _filteredHistory = List.of(_allHistory);
    } else {
      _filteredHistory = _allHistory.where((item) {
        return item.plantName.toLowerCase().contains(query) ||
            item.diseaseName.toLowerCase().contains(query) ||
            item.severity.toLowerCase().contains(query);
      }).toList();
    }
  }

  Future<void> _downloadImagesForItems(List<DiseaseHistoryItem> items) async {
    if (_isRefreshingAfterImageDownload || items.isEmpty) return;

    try {
      final accessToken = await _storage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) return;

      bool anyDownloaded = false;

      for (final item in items) {
        final hasLocalImage =
            item.localPath.isNotEmpty && File(item.localPath).existsSync();
        final serverUrl = item.serverImageUrl;

        if (!hasLocalImage &&
            item.imageId != null &&
            item.imageId!.isNotEmpty &&
            serverUrl != null &&
            serverUrl.isNotEmpty &&
            serverUrl != '/uploads/images/pending') {
          final localPath = await _syncService.downloadImageOnDemand(
            item.imageId!,
            serverUrl,
            accessToken,
          );

          if (localPath != null) {
            anyDownloaded = true;
          }
        }
      }

      if (anyDownloaded && mounted) {
        _isRefreshingAfterImageDownload = true;
        try {
          final userId = await _storage.getUserId();
          if (userId != null) {
            final refreshedAnalyses = await _db.getUserAnalysesPaginated(
              userId,
              limit: _allHistory.length,
              offset: 0,
            );

            final refreshedItems = refreshedAnalyses
                .map((json) => DiseaseHistoryItem.fromJson(json))
                .toList();

            if (!mounted) return;

            setState(() {
              _allHistory
                ..clear()
                ..addAll(refreshedItems);
              _applyFilter();
            });
          }
        } finally {
          _isRefreshingAfterImageDownload = false;
        }
      }
    } catch (e) {
      debugPrint('❌ Error downloading visible images: $e');
    }
  }

  void _handleRetry() {
    _loadInitialHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: 'Detection History',
        showOnlineStatus: true,
      ),
      body: _hasError
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    SmartReTranslator(
                      text: _errorMessage,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const SmartReTranslator(
                        text: 'Retry',
                        style: TextStyle(),
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
                      onPressed: _handleRetry,
                    ),
                  ],
                ),
              ),
            )
          : _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : _allHistory.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    SmartReTranslator(
                      text: 'No disease history found',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    SmartReTranslator(
                      text: 'Analyze a plant to see results here',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SmartReTranslator(
                          text: 'Search by plants, disease, or severity',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.primaryGreen,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = _filteredHistory[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      child: _DiseaseHistoryCard(
                        item: item,
                        onTap: () => _showDetailDialog(context, item),
                      ),
                    );
                  }, childCount: _filteredHistory.length),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      if (_isLoadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: const DisclaimerBanner(
                          'AI results are for reference only. Accuracy depends on image quality and conditions. Always consult an expert before taking action. AGRHI is not liable for crop losses based on these predictions.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: AppColors.primaryGreen,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            )
          : null,
    );
  }

  void _showDetailDialog(BuildContext context, DiseaseHistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => DiseaseDetailDialog(item: item),
    );
  }
}

class _DiseaseHistoryCard extends StatelessWidget {
  final DiseaseHistoryItem item;
  final VoidCallback onTap;

  const _DiseaseHistoryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 3,
      shadowColor: AppColors.primaryGreen.withOpacity(0.13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImage(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmartReTranslator(
                      text: item.plantName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SmartReTranslator(
                      text: item.diseaseName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SmartReTranslator(
                      text: _formatDate(item.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge(
                          'Severity: ${item.severity}',
                          item.severityColor,
                        ),
                        _buildBadge(
                          item.confidencePercent,
                          AppColors.primaryGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildImage() {
    final imagePath = item.imagePath;

    if (imagePath == null || imagePath.isEmpty) {
      return Container(
        width: 90,
        height: 90,
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported, size: 40),
      );
    }

    final file = File(imagePath);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildErrorImage(),
      );
    }

    return _buildErrorImage();
  }

  Widget _buildErrorImage() {
    return Container(
      width: 90,
      height: 90,
      color: Colors.grey[300],
      child: const Icon(Icons.broken_image, size: 40),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SmartReTranslator(
        text: text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class DiseaseDetailDialog extends StatelessWidget {
  final DiseaseHistoryItem item;

  const DiseaseDetailDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: _buildHeaderImage(),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.5),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmartReTranslator(
                      text: item.plantName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SmartReTranslator(
                      text: item.diseaseName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          'Severity: ${item.severity}',
                          item.severityColor,
                          Icons.warning,
                        ),
                        _buildInfoChip(
                          'Confidence: ${item.confidencePercent}',
                          AppColors.primaryGreen,
                          Icons.show_chart,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SmartReTranslator(
                      text: 'Detected on ${item.formattedDate}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (item.remedies.isNotEmpty) ...[
                      _buildSectionTitle('Remedies', Icons.healing),
                      const SizedBox(height: 8),
                      ...item.remedies.map(_buildBulletPoint),
                      const SizedBox(height: 16),
                    ],
                    if (item.preventions.isNotEmpty) ...[
                      _buildSectionTitle('Prevention', Icons.shield),
                      const SizedBox(height: 8),
                      ...item.preventions.map(_buildBulletPoint),
                    ],
                    if (item.remedies.isEmpty && item.preventions.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: SmartReTranslator(
                            text:
                                'No remedies or prevention information available',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderImage() {
    final imagePath = item.imagePath;

    if (imagePath == null || imagePath.isEmpty) {
      return Container(
        width: double.infinity,
        height: 200,
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported, size: 60),
      );
    }

    final file = File(imagePath);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: double.infinity,
          height: 200,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, size: 60),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 200,
      color: Colors.grey[300],
      child: const Icon(Icons.broken_image, size: 60),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryGreen),
        const SizedBox(width: 8),
        SmartReTranslator(
          text: title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: SmartReTranslator(
              text: text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          SmartReTranslator(
            text: label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
