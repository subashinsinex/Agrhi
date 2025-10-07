import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../src/services/language_service.dart';
import '../../../utils/colors.dart';

class LanguageSwitcher extends StatefulWidget {
  final bool showAsIcon;

  const LanguageSwitcher({super.key, this.showAsIcon = true});

  @override
  State<LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<LanguageSwitcher> {
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

    if (mounted) {
      setState(() {
        downloadedLanguages = downloaded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);

    if (widget.showAsIcon) {
      return IconButton(
        icon: Icon(Icons.language, color: AppColors.textWhite),
        onPressed: () => _showLanguageBottomSheet(context, languageService),
        tooltip: 'Language',
      );
    } else {
      return _buildLanguageList(context, languageService);
    }
  }

  void _showLanguageBottomSheet(
    BuildContext context,
    LanguageService languageService,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                        onPressed: () {
                          _showInfoDialog(context);
                        },
                        tooltip: 'About language packs',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Download language packs for offline translation',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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
                            languageService.currentLocale.languageCode ==
                            languageCode;
                        final isDownloaded = downloadedLanguages.contains(
                          languageCode,
                        );
                        final isDownloading =
                            downloadingLanguages[languageCode] ?? false;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryGreen.withOpacity(0.1)
                                : null,
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
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    LanguageService
                                            .languageNames[languageCode] ??
                                        'Unknown',
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primaryGreen
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isDownloaded && !isDownloading)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.successColor.withOpacity(
                                        0.1,
                                      ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation(
                                          AppColors.primaryGreen,
                                        ),
                                        backgroundColor: AppColors.primaryGreen
                                            .withOpacity(0.1),
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isDownloaded &&
                                    !isDownloading &&
                                    languageCode != 'en')
                                  IconButton(
                                    icon: Icon(
                                      Icons.download,
                                      color: AppColors.primaryGreen,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      setModalState(() {
                                        downloadingLanguages[languageCode] =
                                            true;
                                      });
                                      setState(() {
                                        downloadingLanguages[languageCode] =
                                            true;
                                      });

                                      final success = await languageService
                                          .downloadLanguageModel(
                                            languageCode,
                                            allowCellular: true,
                                          );

                                      if (success) {
                                        setModalState(() {
                                          downloadedLanguages.add(languageCode);
                                          downloadingLanguages[languageCode] =
                                              false;
                                        });
                                        setState(() {
                                          downloadedLanguages.add(languageCode);
                                          downloadingLanguages[languageCode] =
                                              false;
                                        });

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '${LanguageService.languageNames[languageCode]} downloaded successfully',
                                              ),
                                              backgroundColor:
                                                  AppColors.successColor,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        setModalState(() {
                                          downloadingLanguages[languageCode] =
                                              false;
                                        });
                                        setState(() {
                                          downloadingLanguages[languageCode] =
                                              false;
                                        });

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Failed to download ${LanguageService.languageNames[languageCode]}. Check your internet connection.',
                                              ),
                                              backgroundColor:
                                                  AppColors.errorColor,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration: const Duration(
                                                seconds: 3,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    tooltip: 'Download language pack',
                                  ),
                                if (isDownloaded &&
                                    !isSelected &&
                                    languageCode != 'en')
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.errorColor,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      final confirm =
                                          await _showDeleteConfirmation(
                                            context,
                                            LanguageService
                                                .languageNames[languageCode]!,
                                          );

                                      if (confirm == true) {
                                        final success = await languageService
                                            .deleteLanguageModel(languageCode);

                                        if (success) {
                                          setModalState(() {
                                            downloadedLanguages.remove(
                                              languageCode,
                                            );
                                          });
                                          setState(() {
                                            downloadedLanguages.remove(
                                              languageCode,
                                            );
                                          });

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${LanguageService.languageNames[languageCode]} deleted',
                                                ),
                                                backgroundColor:
                                                    AppColors.successColor,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                duration: const Duration(
                                                  seconds: 2,
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    tooltip: 'Delete language pack',
                                  ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.primaryGreen,
                                    size: 24,
                                  ),
                              ],
                            ),
                            onTap: isDownloaded && !isDownloading
                                ? () async {
                                    if (isSelected) {
                                      Navigator.pop(bottomSheetContext);
                                      return;
                                    }

                                    Navigator.pop(bottomSheetContext);

                                    // NEW: Show loading with preloading message
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => Container(
                                        color: Colors.black.withOpacity(0.5),
                                        child: Center(
                                          child: Card(
                                            elevation: 8,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.all(32.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 60,
                                                    height: 60,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 4,
                                                      valueColor:
                                                          AlwaysStoppedAnimation(
                                                            AppColors
                                                                .primaryGreen,
                                                          ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 24),
                                                  Text(
                                                    'Changing language...',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'Preparing translations',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );

                                    try {
                                      final previousLocale =
                                          languageService.currentLocale;

                                      // Change language (includes preloading)
                                      await languageService.changeLanguage(
                                        locale,
                                        previousLocale: previousLocale,
                                      );

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(
                                                  Icons.language,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Language changed to ${LanguageService.languageNames[languageCode]}',
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor:
                                                AppColors.successColor,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Error changing language. Defaulting to English.',
                                            ),
                                            backgroundColor:
                                                AppColors.errorColor,
                                            behavior: SnackBarBehavior.floating,
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                            enabled: isDownloaded && !isDownloading,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageList(
    BuildContext context,
    LanguageService languageService,
  ) {
    return Column(
      children: LanguageService.supportedLocales.map((locale) {
        final languageCode = locale.languageCode;
        final isSelected =
            languageService.currentLocale.languageCode == languageCode;
        final isDownloaded = downloadedLanguages.contains(languageCode);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen.withOpacity(0.1) : null,
            borderRadius: BorderRadius.circular(12),
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
            title: Text(
              LanguageService.languageNames[languageCode] ?? 'Unknown',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppColors.primaryGreen
                    : AppColors.textPrimary,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDownloaded)
                  const Icon(
                    Icons.download_done,
                    color: AppColors.successColor,
                    size: 16,
                  ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppColors.primaryGreen),
              ],
            ),
            onTap: isDownloaded
                ? () async {
                    if (isSelected) return;

                    try {
                      final previousLocale = languageService.currentLocale;
                      await languageService.changeLanguage(
                        locale,
                        previousLocale: previousLocale,
                      );
                    } catch (e) {
                      debugPrint('Error changing language: $e');
                    }
                  }
                : null,
            enabled: isDownloaded,
          ),
        );
      }).toList(),
    );
  }

  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    String languageName,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Language Pack'),
        content: Text(
          'Are you sure you want to delete the $languageName language pack? You can download it again later.',
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
          'Download language packs to use offline translation. '
          'Each pack is about 30-40 MB.\n\n'
          'Downloaded packs provide faster, offline translation with automatic caching for instant page loads.\n\n'
          'Tap on a language to switch after downloading. '
          'Delete unused packs to free up storage space.',
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
