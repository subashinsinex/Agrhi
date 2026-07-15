import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../src/services/language_service.dart';
import '../../utils/colors.dart';

class LanguageSwitcher extends StatefulWidget {
  final bool showAsIcon;

  const LanguageSwitcher({super.key, this.showAsIcon = true});

  static void showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _LanguageSwitcherBottomSheet(),
    );
  }

  @override
  State<LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<LanguageSwitcher> {
  @override
  Widget build(BuildContext context) {
    if (widget.showAsIcon) {
      return IconButton(
        icon: Icon(Icons.language, color: AppColors.textWhite),
        onPressed: () => LanguageSwitcher.showBottomSheet(context),
        tooltip: 'Language',
      );
    }
    return const SizedBox.shrink();
  }
}

class _LanguageSwitcherBottomSheet extends StatefulWidget {
  const _LanguageSwitcherBottomSheet();

  @override
  State<_LanguageSwitcherBottomSheet> createState() =>
      _LanguageSwitcherBottomSheetState();
}

class _LanguageSwitcherBottomSheetState
    extends State<_LanguageSwitcherBottomSheet> {
  Set<String> downloadedLanguages = {'en'};
  Map<String, bool> downloadingLanguages = {};

  @override
  void initState() {
    super.initState();
    _loadDownloadedLanguages();
  }

  Future<void> _loadDownloadedLanguages() async {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );
    final downloaded = await languageService.getDownloadedLanguages();
    if (mounted) setState(() => downloadedLanguages = downloaded);
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.language, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              const Text(
                'Language',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                onPressed: () => _showInfoDialog(context),
                tooltip: 'About language packs',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Download language packs for offline translation',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: LanguageService.supportedLocales.length,
              itemBuilder: (context, index) {
                final locale = LanguageService.supportedLocales[index];
                final languageCode = locale.languageCode;
                final isSelected =
                    languageService.currentLocale.languageCode == languageCode;
                final isDownloaded = downloadedLanguages.contains(languageCode);
                final isDownloading =
                    downloadingLanguages[languageCode] ?? false;

                return _buildLanguageItem(
                  context,
                  languageService,
                  locale,
                  languageCode,
                  isSelected,
                  isDownloaded,
                  isDownloading,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLanguageItem(
    BuildContext context,
    LanguageService languageService,
    Locale locale,
    String languageCode,
    bool isSelected,
    bool isDownloaded,
    bool isDownloading,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryGreen.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryGreen.withOpacity(0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? AppColors.primaryGreen
              : AppColors.primaryGreen.withOpacity(0.1),
          child: Text(
            languageCode.toUpperCase(),
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.primaryGreen,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                LanguageService.languageNames[languageCode] ?? 'Unknown',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (isDownloaded && !isDownloading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: AppColors.successColor,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Downloaded',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: isDownloading
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.primaryGreen),
                    backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Downloading... (~30-40 MB)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            : null,
        trailing: _buildTrailingActions(
          context,
          languageService,
          languageCode,
          isSelected,
          isDownloaded,
          isDownloading,
        ),
        onTap: isDownloaded && !isDownloading
            ? () => _handleLanguageSwitch(
                context,
                languageService,
                locale,
                languageCode,
                isSelected,
              )
            : null,
        enabled: isDownloaded && !isDownloading,
      ),
    );
  }

  Widget _buildTrailingActions(
    BuildContext context,
    LanguageService languageService,
    String languageCode,
    bool isSelected,
    bool isDownloaded,
    bool isDownloading,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isDownloaded && !isDownloading && languageCode != 'en')
          IconButton(
            icon: Icon(Icons.download, color: AppColors.primaryGreen, size: 20),
            onPressed: () =>
                _handleDownload(context, languageService, languageCode),
            tooltip: 'Download language pack',
          ),
        if (isDownloaded && !isSelected && languageCode != 'en')
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.errorColor,
              size: 20,
            ),
            onPressed: () =>
                _handleDelete(context, languageService, languageCode),
            tooltip: 'Delete language pack',
          ),
        if (isSelected)
          const Icon(
            Icons.check_circle,
            color: AppColors.primaryGreen,
            size: 24,
          ),
      ],
    );
  }

  Future<void> _handleDownload(
    BuildContext context,
    LanguageService languageService,
    String languageCode,
  ) async {
    setState(() => downloadingLanguages[languageCode] = true);

    final success = await languageService.downloadLanguageModel(
      languageCode,
      allowCellular: true,
    );

    if (mounted) {
      setState(() {
        if (success) downloadedLanguages.add(languageCode);
        downloadingLanguages[languageCode] = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '${LanguageService.languageNames[languageCode]} downloaded successfully'
                  : 'Failed to download ${LanguageService.languageNames[languageCode]}',
            ),
            backgroundColor: success
                ? AppColors.successColor
                : AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: success ? 2 : 3),
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(
    BuildContext context,
    LanguageService languageService,
    String languageCode,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Language Pack'),
        content: Text(
          'Are you sure you want to delete the ${LanguageService.languageNames[languageCode]} language pack?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await languageService.deleteLanguageModel(languageCode);
      if (success && mounted) {
        setState(() => downloadedLanguages.remove(languageCode));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${LanguageService.languageNames[languageCode]} deleted',
              ),
              backgroundColor: AppColors.successColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleLanguageSwitch(
    BuildContext context,
    LanguageService languageService,
    Locale locale,
    String languageCode,
    bool isSelected,
  ) async {
    if (isSelected) {
      Navigator.pop(context);
      return;
    }

    Navigator.pop(context);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Switching to ${LanguageService.languageNames[languageCode]}...',
              ),
            ],
          ),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
        ),
      );

      try {
        await languageService.changeLanguage(
          locale,
          previousLocale: languageService.currentLocale,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Language changed to ${LanguageService.languageNames[languageCode]}',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.successColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error changing language'),
              backgroundColor: AppColors.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: AppColors.primaryGreen),
            SizedBox(width: 8),
            Text('About Language Packs', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          'Download language packs to use offline translation. Each pack is about 30-40 MB.\n\n'
          'Downloaded packs provide faster, offline translation.\n\n'
          'Tap on a language to switch after downloading.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
