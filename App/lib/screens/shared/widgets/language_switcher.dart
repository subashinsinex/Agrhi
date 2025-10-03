import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../src/services/language_service.dart';
import '../../../utils/colors.dart';
import '../../../flutter_gen/gen_l10n/app_localizations.dart';

class LanguageSwitcher extends StatelessWidget {
  final bool showAsIcon;

  const LanguageSwitcher({super.key, this.showAsIcon = true});

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final l10n = AppLocalizations.of(context);

    if (showAsIcon) {
      return IconButton(
        icon: Icon(Icons.language, color: AppColors.textWhite),
        onPressed: () =>
            _showLanguageBottomSheet(context, languageService, l10n),
        tooltip: l10n.language,
      );
    } else {
      return _buildLanguageList(context, languageService, l10n);
    }
  }

  void _showLanguageBottomSheet(
    BuildContext context,
    LanguageService languageService,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Icon(Icons.language, color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Text(
                    l10n.language,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Language options
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: LanguageService.supportedLocales.length,
                  itemBuilder: (context, index) {
                    final locale = LanguageService.supportedLocales[index];
                    final isSelected =
                        languageService.currentLocale.languageCode ==
                        locale.languageCode;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryGreen.withOpacity(0.1)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? AppColors.primaryGreen
                              : AppColors.primaryGreen.withOpacity(0.1),
                          child: Text(
                            locale.languageCode.toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          LanguageService.languageNames[locale.languageCode] ??
                              'Unknown',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primaryGreen
                                : AppColors.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: AppColors.primaryGreen,
                              )
                            : null,
                        onTap: () {
                          languageService.changeLanguage(locale);
                          Navigator.pop(bottomSheetContext);

                          // Show confirmation
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.language,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Language changed to ${LanguageService.languageNames[locale.languageCode]}',
                                  ),
                                ],
                              ),
                              backgroundColor: AppColors.successColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
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
  }

  Widget _buildLanguageList(
    BuildContext context,
    LanguageService languageService,
    AppLocalizations l10n,
  ) {
    return Column(
      children: LanguageService.supportedLocales.map((locale) {
        final isSelected =
            languageService.currentLocale.languageCode == locale.languageCode;

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
                locale.languageCode.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(
              LanguageService.languageNames[locale.languageCode] ?? 'Unknown',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppColors.primaryGreen
                    : AppColors.textPrimary,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: AppColors.primaryGreen)
                : null,
            onTap: () => languageService.changeLanguage(locale),
          ),
        );
      }).toList(),
    );
  }
}
