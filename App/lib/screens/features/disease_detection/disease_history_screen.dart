import 'dart:io';
import 'package:flutter/material.dart';
import '../../../utils/colors.dart';
import '../../../src/database/database_helper.dart';
import '../../shared/custom_app_bar.dart';
import '../../../utils/storage_helper.dart';
import '../../shared/smart_retranslator.dart';

/// Model for Disease History Item
class DiseaseHistoryItem {
  final String id;
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
    // Parse remedies and preventions from GROUP_CONCAT string
    final remediesStr = json['remedies'] as String?;
    final preventionsStr = json['preventions'] as String?;

    final remedies = remediesStr != null && remediesStr.isNotEmpty
        ? remediesStr.split('|||').where((s) => s.isNotEmpty).toList()
        : <String>[];

    final preventions = preventionsStr != null && preventionsStr.isNotEmpty
        ? preventionsStr.split('|||').where((s) => s.isNotEmpty).toList()
        : <String>[];

    return DiseaseHistoryItem(
      id: json['id'] ?? '',
      plantName: json['plant_name'] ?? 'Unknown Plant',
      diseaseName: json['disease_name'] ?? 'Unknown Disease',
      severity: json['severity'] ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      localPath: json['local_path'] ?? '',
      serverImageUrl: json['server_image_url'],
      createdAt: json['created_at'] ?? '',
      remedies: remedies,
      preventions: preventions,
    );
  }

  /// Get formatted confidence percentage
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Get severity color
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

  /// Get image path (local or server)
  String? get imagePath {
    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      return localPath;
    }
    return serverImageUrl;
  }

  /// Format date
  String get formattedDate {
    try {
      final date = DateTime.parse(createdAt);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return createdAt;
    }
  }
}

/// Disease History Screen
class DiseaseHistoryScreen extends StatefulWidget {
  const DiseaseHistoryScreen({super.key});

  @override
  State<DiseaseHistoryScreen> createState() => _DiseaseHistoryScreenState();
}

class _DiseaseHistoryScreenState extends State<DiseaseHistoryScreen> {
  late Future<List<DiseaseHistoryItem>> _futureHistory;
  List<DiseaseHistoryItem> _allHistory = [];
  List<DiseaseHistoryItem> _filteredHistory = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final StorageHelper _storage = StorageHelper();

  bool _hasError = false;
  bool _showScrollToTop = false;
  String _errorMessage = 'Failed to load disease history';

  @override
  void initState() {
    super.initState();
    _fetchData();
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
      setState(() {
        _showScrollToTop = true;
      });
    } else if (_scrollController.offset <= 200 && _showScrollToTop) {
      setState(() {
        _showScrollToTop = false;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  void _fetchData() {
    _futureHistory = _loadDiseaseHistory();
  }

  Future<List<DiseaseHistoryItem>> _loadDiseaseHistory() async {
    try {
      final userId = await _storage.getUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }

      print('📥 Loading disease history for user: $userId');

      // Fetch user analyses from database
      final analyses = await _db.getUserAnalyses(userId);

      print('✅ Loaded ${analyses.length} disease history items');

      final historyItems = analyses
          .map((json) => DiseaseHistoryItem.fromJson(json))
          .toList();

      setState(() {
        _allHistory = historyItems;
        _filteredHistory = List.of(_allHistory);
        _hasError = false;
      });

      return historyItems;
    } catch (e) {
      print('❌ Error loading disease history: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load disease history: $e';
      });
      rethrow;
    }
  }

  void _filterHistory() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredHistory = List.of(_allHistory);
      } else {
        _filteredHistory = _allHistory.where((item) {
          return item.plantName.toLowerCase().contains(query) ||
              item.diseaseName.toLowerCase().contains(query) ||
              item.severity.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _handleRetry() {
    setState(() {
      _hasError = false;
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const CustomAppBar(
        title: 'Detection History',
        showOnlineStatus: true,
        showLanguageSwitcher: false,
      ),
      body: _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SmartReTranslator(
                      text: _errorMessage,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: SmartReTranslator(
                      text: 'Retry',
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
                    onPressed: _handleRetry,
                  ),
                ],
              ),
            )
          : FutureBuilder<List<DiseaseHistoryItem>>(
              future: _futureHistory,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const SizedBox.shrink();
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        SmartReTranslator(
                          text: 'No disease history found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SmartReTranslator(
                          text: 'Analyze a plant to see results here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SmartReTranslator(
                                text: 'Search by plants, disease, or severity',
                                style: const TextStyle(
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
                    ],
                  );
                }
              },
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

/// Disease History Card Widget
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
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImage(),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plant Name - TRANSLATED
                    SmartReTranslator(
                      text: item.plantName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Disease Name - TRANSLATED
                    SmartReTranslator(
                      text: item.diseaseName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Date
                    SmartReTranslator(
                      text: _formatDate(item.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    // Severity and Confidence - TRANSLATED
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

    // Local image
    if (imagePath.startsWith('/') || imagePath.startsWith('file://')) {
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
    }

    // Network image
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildErrorImage(),
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 90,
            height: 90,
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
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

/// Disease Detail Dialog
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
            // Header with image
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
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plant and Disease - TRANSLATED
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
                    // Badges - TRANSLATED
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
                    // Remedies - TRANSLATED
                    if (item.remedies.isNotEmpty) ...[
                      _buildSectionTitle('Remedies', Icons.healing),
                      const SizedBox(height: 8),
                      ...item.remedies.map(
                        (remedy) => _buildBulletPoint(remedy),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Preventions - TRANSLATED
                    if (item.preventions.isNotEmpty) ...[
                      _buildSectionTitle('Prevention', Icons.shield),
                      const SizedBox(height: 8),
                      ...item.preventions.map(
                        (prevention) => _buildBulletPoint(prevention),
                      ),
                    ],
                    // Empty state - TRANSLATED
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

    if (imagePath.startsWith('/') || imagePath.startsWith('file://')) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
        );
      }
    }

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
        },
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
