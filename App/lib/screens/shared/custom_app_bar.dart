import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../src/services/language_service.dart';
import '../../src/services/connectivity_manager.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool centerTitle;
  final VoidCallback? onBackPressed;
  final VoidCallback? onMenuPressed;
  final bool showOnlineStatus;

  const CustomAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle = false,
    this.onBackPressed,
    this.onMenuPressed,
    this.showOnlineStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: _buildTitle(context),
      actions: _buildActions(),
      leading: leading ?? _buildLeading(context),
      automaticallyImplyLeading: false,
      backgroundColor: backgroundColor ?? AppColors.appBarBackground,
      foregroundColor: foregroundColor ?? AppColors.textWhite,
      elevation: elevation ?? 2,
      shadowColor: AppColors.shadowColor.withOpacity(0.3),
      scrolledUnderElevation: elevation ?? 4,
      centerTitle: centerTitle,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 70,
    );
  }

  List<Widget>? _buildActions() {
    final actionsList = <Widget>[];

    if (showOnlineStatus) {
      actionsList.add(const _OnlineStatusIcon());
    }

    if (actions != null) {
      actionsList.addAll(actions!);
    }

    return actionsList.isEmpty ? null : actionsList;
  }

  Widget? _buildTitle(BuildContext context) {
    if (title == null && subtitle == null) return null;

    if (subtitle != null && title != null) {
      return _TitleWithSubtitle(
        title: title!,
        subtitle: subtitle!,
        centerTitle: centerTitle,
        foregroundColor: foregroundColor,
      );
    }

    if (title != null) {
      return _TranslatedText(
        text: title!,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: foregroundColor ?? AppColors.textWhite,
          fontWeight: FontWeight.w600,
          fontSize: 22,
          letterSpacing: 0.15,
        ),
      );
    }

    return null;
  }

  Widget? _buildLeading(BuildContext context) {
    if (onMenuPressed != null) {
      return _IconButtonWidget(
        icon: Icons.menu,
        onPressed: onMenuPressed!,
        tooltip: 'Menu',
        color: foregroundColor,
      );
    }

    if (onBackPressed != null ||
        (automaticallyImplyLeading && Navigator.of(context).canPop())) {
      return _IconButtonWidget(
        icon: Icons.arrow_back,
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
        tooltip: 'Back',
        color: foregroundColor,
      );
    }

    return null;
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

// ==================== Helper Widgets ====================

class _TranslatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextOverflow? overflow;
  final int? maxLines;

  const _TranslatedText({
    required this.text,
    this.style,
    // ignore: unused_element_parameter
    this.overflow,
    // ignore: unused_element_parameter
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    return FutureBuilder<String>(
      future: languageService.translate(text),
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? text,
          style: style,
          overflow: overflow ?? TextOverflow.ellipsis,
          maxLines: maxLines ?? 1,
        );
      },
    );
  }
}

class _TitleWithSubtitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool centerTitle;
  final Color? foregroundColor;

  const _TitleWithSubtitle({
    required this.title,
    required this.subtitle,
    required this.centerTitle,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centerTitle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TranslatedText(
          text: title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: foregroundColor ?? AppColors.textWhite,
            fontWeight: FontWeight.w600,
            fontSize: 22,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 4),
        _TranslatedText(
          text: subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: (foregroundColor ?? AppColors.textWhite).withOpacity(0.85),
            fontWeight: FontWeight.w400,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _IconButtonWidget extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? color;

  const _IconButtonWidget({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color ?? AppColors.textWhite, size: 26),
      onPressed: onPressed,
      tooltip: tooltip,
      splashRadius: 24,
    );
  }
}

// ==================== Online Status Icon ====================

class _OnlineStatusIcon extends StatelessWidget {
  const _OnlineStatusIcon();

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityManager>(
      builder: (context, connectivityManager, _) {
        final isOnline = connectivityManager.isOnline;
        final isSyncing = connectivityManager.isSyncing;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: _getTooltipMessage(isOnline, isSyncing),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getBackgroundColor(isOnline, isSyncing),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: _buildStatusIcon(isOnline, isSyncing),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(bool isOnline, bool isSyncing) {
    if (isSyncing) {
      return const SizedBox(
        key: ValueKey('syncing'),
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      );
    } else if (isOnline) {
      return const Icon(
        key: ValueKey('online'),
        Icons.cloud_done_rounded,
        color: Colors.white,
        size: 16,
      );
    } else {
      return const Icon(
        key: ValueKey('offline'),
        Icons.cloud_off_rounded,
        color: Colors.white,
        size: 16,
      );
    }
  }

  Color _getBackgroundColor(bool isOnline, bool isSyncing) {
    if (isSyncing) {
      return Colors.blue.shade600.withOpacity(0.9);
    } else if (isOnline) {
      return AppColors.secondaryGreen.withOpacity(0.9);
    } else {
      return AppColors.errorColor.withOpacity(0.9);
    }
  }

  String _getTooltipMessage(bool isOnline, bool isSyncing) {
    if (isSyncing) {
      return 'Syncing data with server...';
    } else if (isOnline) {
      return 'Connected to internet';
    } else {
      return 'No internet connection';
    }
  }
}

// ==================== Dashboard AppBar ====================

class DashboardAppBar extends CustomAppBar {
  const DashboardAppBar({super.key, super.actions})
    : super(
        title: 'Welcome',
        subtitle: 'Enjoy our Services',
        automaticallyImplyLeading: false,
        onMenuPressed: null,
        showOnlineStatus: true,
      );

  DashboardAppBar.withSettings({
    super.key,
    required VoidCallback? onSyncPressed,
    required VoidCallback onHelpPressed,
    required VoidCallback onLogoutPressed,
    required VoidCallback onLanguagePressed,
    required bool isSyncing,
  }) : super(
         title: 'Welcome',
         subtitle: 'Enjoy our Services',
         automaticallyImplyLeading: false,
         showOnlineStatus: true,
         actions: [
           _SettingsDropdownButton(
             onSyncPressed: onSyncPressed,
             onHelpPressed: onHelpPressed,
             onLogoutPressed: onLogoutPressed,
             onLanguagePressed: onLanguagePressed,
             isSyncing: isSyncing,
           ),
         ],
       );
}

// ==================== Settings Dropdown ====================

class _SettingsDropdownButton extends StatelessWidget {
  final VoidCallback? onSyncPressed;
  final VoidCallback onHelpPressed;
  final VoidCallback onLogoutPressed;
  final VoidCallback onLanguagePressed;
  final bool isSyncing;

  const _SettingsDropdownButton({
    required this.onSyncPressed,
    required this.onHelpPressed,
    required this.onLogoutPressed,
    required this.onLanguagePressed,
    required this.isSyncing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.settings_outlined,
          color: AppColors.textWhite,
          size: 26,
        ),
        tooltip: 'Settings',
        offset: const Offset(0, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.primaryWhite.withOpacity(0.95),
        elevation: 8,
        splashRadius: 24,
        padding: EdgeInsets.zero,
        itemBuilder: (BuildContext context) => [
          _buildLanguageMenuItem(context),
          const PopupMenuDivider(height: 1),
          _buildSyncMenuItem(context),
          _buildHelpMenuItem(context),
          const PopupMenuDivider(height: 1),
          _buildLogoutMenuItem(context),
        ],
        onSelected: (String value) {
          switch (value) {
            case 'language':
              onLanguagePressed();
              break;
            case 'sync':
              onSyncPressed?.call();
              break;
            case 'help':
              onHelpPressed();
              break;
            case 'logout':
              onLogoutPressed();
              break;
          }
        },
      ),
    );
  }

  PopupMenuItem<String> _buildLanguageMenuItem(BuildContext context) {
    return PopupMenuItem<String>(
      value: 'language',
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Consumer<LanguageService>(
        builder: (context, langService, _) {
          final languageCode = langService.currentLocale.languageCode;

          return FutureBuilder<String>(
            future: langService.translate('Language'),
            builder: (context, snapshot) {
              return Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.language_outlined,
                        color: Colors.purple,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          snapshot.data ?? 'Language',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _getLanguageDisplayName(languageCode),
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  PopupMenuItem<String> _buildSyncMenuItem(BuildContext context) {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    return PopupMenuItem<String>(
      value: 'sync',
      enabled: !isSyncing && onSyncPressed != null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Consumer<ConnectivityManager>(
        builder: (context, connectivityManager, _) {
          return FutureBuilder<String>(
            future: languageService.translate('Sync'),
            builder: (context, snapshot) {
              return Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (isSyncing || onSyncPressed == null)
                          ? AppColors.textSecondary.withOpacity(0.1)
                          : AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : Icon(
                              Icons.sync_outlined,
                              color: onSyncPressed == null
                                  ? AppColors.textSecondary
                                  : AppColors.primaryGreen,
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          snapshot.data ?? 'Sync',
                          style: TextStyle(
                            color: (isSyncing || onSyncPressed == null)
                                ? AppColors.textSecondary.withOpacity(0.5)
                                : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          connectivityManager.syncStatusMessage,
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  PopupMenuItem<String> _buildHelpMenuItem(BuildContext context) {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    return PopupMenuItem<String>(
      value: 'help',
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: FutureBuilder<String>(
        future: languageService.translate('Help & Support'),
        builder: (context, snapshot) {
          return Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.help_outline, color: Colors.blue, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  snapshot.data ?? 'Help & Support',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PopupMenuItem<String> _buildLogoutMenuItem(BuildContext context) {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    return PopupMenuItem<String>(
      value: 'logout',
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: FutureBuilder<String>(
        future: languageService.translate('Logout'),
        builder: (context, snapshot) {
          return Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.logout,
                    color: AppColors.errorColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  snapshot.data ?? 'Logout',
                  style: const TextStyle(
                    color: AppColors.errorColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getLanguageDisplayName(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'en':
        return 'English';
      case 'ta':
        return 'தமிழ்';
      case 'hi':
        return 'हिन्दी';
      case 'te':
        return 'తెలుగు';
      case 'kn':
        return 'ಕನ್ನಡ';
      case 'ml':
        return 'മലയാളം';
      default:
        return languageCode.toUpperCase();
    }
  }
}

// ==================== Predefined AppBars ====================

class FeatureAppBar extends CustomAppBar {
  const FeatureAppBar({
    super.key,
    required String featureName,
    super.actions,
    super.onBackPressed,
    super.showOnlineStatus = true,
  }) : super(title: featureName, centerTitle: true);
}

class ProfileAppBar extends CustomAppBar {
  final String userName;

  const ProfileAppBar({
    super.key,
    required this.userName,
    super.actions,
    super.onBackPressed,
    super.showOnlineStatus = true,
  }) : super(title: 'Profile', subtitle: 'Hello, $userName');
}

class MenuAppBar extends CustomAppBar {
  const MenuAppBar({
    super.key,
    required String super.title,
    super.subtitle,
    super.actions,
    required VoidCallback super.onMenuPressed,
    super.showOnlineStatus = true,
  }) : super(automaticallyImplyLeading: false);
}

class BackAppBar extends CustomAppBar {
  const BackAppBar({
    super.key,
    required String super.title,
    super.subtitle,
    super.actions,
    super.onBackPressed,
    super.showOnlineStatus = true,
  });
}
