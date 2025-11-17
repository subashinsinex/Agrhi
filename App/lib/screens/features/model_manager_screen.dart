import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../src/services/model_manager_provider.dart';
import '../../src/services/model_download_service.dart';
import '../../utils/colors.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );
    _headerController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ModelManagerProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  List<String> _getDownloadingModels(ModelManagerProvider provider) {
    return provider.modelStatuses.entries
        .where((entry) => entry.value == ModelDownloadStatus.downloading)
        .map((entry) => entry.key)
        .toList();
  }

  bool _hasActiveDownloads(ModelManagerProvider provider) {
    return _getDownloadingModels(provider).isNotEmpty;
  }

  Future<void> _cancelAllDownloads(ModelManagerProvider provider) async {
    final downloadingModels = _getDownloadingModels(provider);
    for (final cropName in downloadingModels) {
      await provider.cancelDownload(cropName);
    }
  }

  Future<bool> _onWillPop(ModelManagerProvider provider) async {
    if (_hasActiveDownloads(provider)) {
      final shouldExit = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.errorColor),
              const SizedBox(width: 12),
              const Text('Download in Progress'),
            ],
          ),
          content: const Text(
            'Models are currently downloading. Leaving now will cancel all ongoing downloads. '
            'You can re-download them anytime.\n\nDo you want to exit?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel Downloads & Exit'),
            ),
          ],
        ),
      );

      if (shouldExit == true) {
        await _cancelAllDownloads(provider);
        return true;
      }
      return false;
    }
    return true;
  }

  Future<void> _handleBackNavigation(ModelManagerProvider provider) async {
    final shouldPop = await _onWillPop(provider);
    if (shouldPop && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ModelManagerProvider>(
      builder: (context, provider, child) {
        return PopScope(
          canPop: !_hasActiveDownloads(provider),
          onPopInvoked: (didPop) async {
            if (didPop) return;
            final shouldPop = await _onWillPop(provider);
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('AI Model Manager'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _handleBackNavigation(provider),
              ),
            ),
            backgroundColor: AppColors.backgroundColor,
            body: _buildBody(provider),
          ),
        );
      },
    );
  }

  Widget _buildBody(ModelManagerProvider provider) {
    if (provider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading models...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final downloadedCount = provider.modelStatuses.values
        .where((s) => s == ModelDownloadStatus.downloaded)
        .length;
    final totalCount = ModelDownloadService.modelInfo.length;
    final models = ModelDownloadService.modelInfo.keys.toList();

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Animated Storage Header
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.5),
                  end: Offset.zero,
                ).animate(_headerAnimation),
                child: _buildStorageHeader(
                  provider.totalSize,
                  downloadedCount,
                  totalCount,
                ),
              ),
            ),
          ),

          // Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Text(
                    'Available Models',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$totalCount crops',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Model List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: _buildModelListItem(context, models[index], provider),
                );
              }, childCount: totalCount),
            ),
          ),

          // Bottom Spacing
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildStorageHeader(double totalSize, int downloaded, int total) {
    final percentage = total > 0 ? downloaded / total : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGreen,
            AppColors.primaryGreen.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 20),
              // Stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Models Library',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStatChip(
                          '${totalSize.toStringAsFixed(1)} MB',
                          Icons.storage,
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          '$downloaded/$total',
                          Icons.check_circle_outline,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Circular Progress
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  strokeWidth: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Linear Progress
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1000),
                    tween: Tween(begin: 0.0, end: percentage),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 10,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelListItem(
    BuildContext context,
    String cropName,
    ModelManagerProvider provider,
  ) {
    final info = ModelDownloadService.modelInfo[cropName]!;
    final status =
        provider.modelStatuses[cropName] ?? ModelDownloadStatus.notDownloaded;
    final progress = provider.downloadProgress[cropName] ?? 0.0;
    final isDownloading = status == ModelDownloadStatus.downloading;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDownloading
              ? null
              : () => _handleAction(context, cropName, status, provider),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon with Gradient Background
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getStatusColor(status).withOpacity(0.2),
                        _getStatusColor(status).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _getCropIcon(cropName),
                    color: _getStatusColor(status),
                    size: 28,
                  ),
                ),

                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cropName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (isDownloading)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: AppColors.primaryGreen
                                          .withOpacity(0.15),
                                      valueColor: AlwaysStoppedAnimation(
                                        AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Downloading...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              Icons.storage_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${info.size.toStringAsFixed(1)} MB',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (status == ModelDownloadStatus.downloaded) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successColor.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check,
                                      size: 12,
                                      color: AppColors.successColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Ready',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.successColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Action Button
                if (!isDownloading)
                  _buildActionButton(context, cropName, status, provider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String cropName,
    ModelDownloadStatus status,
    ModelManagerProvider provider,
  ) {
    final isDownloaded = status == ModelDownloadStatus.downloaded;

    return Material(
      color: isDownloaded
          ? AppColors.errorColor.withOpacity(0.1)
          : AppColors.primaryGreen.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _handleAction(context, cropName, status, provider),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(
            isDownloaded ? Icons.delete_outline : Icons.download_rounded,
            color: isDownloaded ? AppColors.errorColor : AppColors.primaryGreen,
            size: 22,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ModelDownloadStatus status) {
    switch (status) {
      case ModelDownloadStatus.downloaded:
        return AppColors.successColor;
      case ModelDownloadStatus.downloading:
        return AppColors.infoColor;
      case ModelDownloadStatus.error:
        return AppColors.errorColor;
      default:
        return AppColors.primaryGreen;
    }
  }

  IconData _getCropIcon(String crop) {
    switch (crop.toLowerCase()) {
      case 'corn':
        return Icons.grain;
      case 'rice':
        return Icons.rice_bowl;
      case 'cotton':
        return Icons.agriculture;
      case 'banana':
        return Icons.food_bank;
      case 'coffee':
        return Icons.coffee;
      case 'tomato':
        return Icons.local_grocery_store;
      case 'coconut':
        return Icons.eco;
      case 'sugarcane':
        return Icons.grass;
      case 'wheat':
        return Icons.bakery_dining;
      case 'groundnut':
        return Icons.nature;
      default:
        return Icons.eco;
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    String cropName,
    ModelDownloadStatus status,
    ModelManagerProvider provider,
  ) async {
    if (status == ModelDownloadStatus.downloaded) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: AppColors.errorColor),
              const SizedBox(width: 12),
              const Text('Delete Model'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete the $cropName model? '
            'This will free up ${ModelDownloadService.modelInfo[cropName]!.size.toStringAsFixed(1)} MB of storage.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await provider.deleteModel(cropName);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('$cropName model deleted successfully'),
                ],
              ),
              backgroundColor: AppColors.infoColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } else if (status == ModelDownloadStatus.notDownloaded) {
      try {
        await provider.downloadModel(cropName);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('$cropName model downloaded successfully'),
                ],
              ),
              backgroundColor: AppColors.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Download failed: $e')),
                ],
              ),
              backgroundColor: AppColors.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }
}
