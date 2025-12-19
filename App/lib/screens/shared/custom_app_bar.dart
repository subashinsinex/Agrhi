import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../src/services/language_service.dart';
import 'language_switcher.dart';

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
  final bool showLanguageSwitcher;

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
    this.showLanguageSwitcher = false,
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
      toolbarHeight: 70, // ✅ INCREASED: Default is 56, now 70
    );
  }

  List<Widget>? _buildActions() {
    final actionsList = <Widget>[];

    if (showLanguageSwitcher) {
      actionsList.add(const LanguageSwitcher(showAsIcon: true));
    }

    if (actions != null) {
      actionsList.addAll(actions!);
    }

    return actionsList.isEmpty ? null : actionsList;
  }

  Widget? _buildTitle(BuildContext context) {
    if (title == null && subtitle == null) return null;

    final languageService = Provider.of<LanguageService>(context);

    if (subtitle != null && title != null) {
      return Column(
        crossAxisAlignment: centerTitle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<String>(
            future: languageService.translate(title!),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? title!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foregroundColor ?? AppColors.textWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 22, // ✅ INCREASED: From 20 to 22
                  letterSpacing: 0.15,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              );
            },
          ),
          const SizedBox(height: 4), // ✅ INCREASED: From 2 to 4
          FutureBuilder<String>(
            future: languageService.translate(subtitle!),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: (foregroundColor ?? AppColors.textWhite).withOpacity(
                    0.85,
                  ),
                  fontWeight: FontWeight.w400,
                  fontSize: 14, // ✅ INCREASED: From 13 to 14
                  letterSpacing: 0.1,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              );
            },
          ),
        ],
      );
    }

    if (title != null) {
      return FutureBuilder<String>(
        future: languageService.translate(title!),
        builder: (context, snapshot) {
          return Text(
            snapshot.data ?? title!,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: foregroundColor ?? AppColors.textWhite,
              fontWeight: FontWeight.w600,
              fontSize: 22, // ✅ INCREASED: From 20 to 22
              letterSpacing: 0.15,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          );
        },
      );
    }

    return null;
  }

  Widget? _buildLeading(BuildContext context) {
    if (onMenuPressed != null) {
      return IconButton(
        icon: Icon(
          Icons.menu,
          color: foregroundColor ?? AppColors.textWhite,
          size: 26, // ✅ INCREASED: From 24 to 26
        ),
        onPressed: onMenuPressed,
        tooltip: 'Menu',
        splashRadius: 24,
      );
    } else if (onBackPressed != null) {
      return IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: foregroundColor ?? AppColors.textWhite,
          size: 26, // ✅ INCREASED: From 24 to 26
        ),
        onPressed: onBackPressed,
        tooltip: 'Back',
        splashRadius: 24,
      );
    } else if (automaticallyImplyLeading && Navigator.of(context).canPop()) {
      return IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: foregroundColor ?? AppColors.textWhite,
          size: 26, // ✅ INCREASED: From 24 to 26
        ),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
        splashRadius: 24,
      );
    }
    return null;
  }

  @override
  Size get preferredSize => const Size.fromHeight(70); // ✅ INCREASED: From kToolbarHeight (56) to 70
}

class DashboardAppBar extends CustomAppBar {
  const DashboardAppBar({super.key, super.actions})
    : super(
        title: 'Welcome',
        subtitle: 'Enjoy our Services',
        automaticallyImplyLeading: false,
        onMenuPressed: null,
        showLanguageSwitcher: false,
      );

  DashboardAppBar.withSettings({
    super.key,
    required VoidCallback? onSyncPressed,
    required VoidCallback onHelpPressed,
    required VoidCallback onLogoutPressed,
    required bool isSyncing,
  }) : super(
         title: 'Welcome',
         subtitle: 'Enjoy our Services',
         automaticallyImplyLeading: false,
         showLanguageSwitcher: true,
         actions: [
           _SettingsDropdownButton(
             onSyncPressed: onSyncPressed,
             onHelpPressed: onHelpPressed,
             onLogoutPressed: onLogoutPressed,
             isSyncing: isSyncing,
           ),
         ],
       );
}

class _SettingsDropdownButton extends StatelessWidget {
  final VoidCallback? onSyncPressed;
  final VoidCallback onHelpPressed;
  final VoidCallback onLogoutPressed;
  final bool isSyncing;

  const _SettingsDropdownButton({
    required this.onSyncPressed,
    required this.onHelpPressed,
    required this.onLogoutPressed,
    required this.isSyncing,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.settings_outlined,
          color: AppColors.textWhite,
          size: 26, // ✅ INCREASED: From 24 to 26
        ),
        tooltip: 'Settings',
        offset: const Offset(
          0,
          60,
        ), // ✅ ADJUSTED: Increased from 52 to 60 to match new height
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.primaryWhite.withOpacity(0.95),
        elevation: 8,
        splashRadius: 24,
        padding: EdgeInsets.zero,
        itemBuilder: (BuildContext context) => [
          // ✅ Sync Option
          PopupMenuItem<String>(
            value: 'sync',
            enabled: !isSyncing,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: FutureBuilder<String>(
              future: languageService.translate('Sync'),
              builder: (context, snapshot) {
                return Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSyncing
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
                                color: AppColors.primaryGreen,
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
                              color: isSyncing
                                  ? AppColors.textSecondary.withOpacity(0.5)
                                  : AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isSyncing)
                            Text(
                              'In progress...',
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
            ),
          ),

          // ✅ Help & Support Option
          PopupMenuItem<String>(
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
                        child: Icon(
                          Icons.help_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
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
          ),

          // ✅ Divider with proper spacing
          const PopupMenuDivider(height: 1),

          // ✅ Logout Option
          PopupMenuItem<String>(
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
                      child: Center(
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
                        style: TextStyle(
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
          ),
        ],
        onSelected: (String value) {
          switch (value) {
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
}

class FeatureAppBar extends CustomAppBar {
  const FeatureAppBar({
    super.key,
    required String featureName,
    super.actions,
    super.onBackPressed,
    super.showLanguageSwitcher,
  }) : super(title: featureName, centerTitle: true);
}

class ProfileAppBar extends CustomAppBar {
  final String userName;

  const ProfileAppBar({
    super.key,
    required this.userName,
    super.actions,
    super.onBackPressed,
    super.showLanguageSwitcher,
  }) : super(title: 'Profile', subtitle: 'Hello, $userName');
}

class MenuAppBar extends CustomAppBar {
  const MenuAppBar({
    super.key,
    required String super.title,
    super.subtitle,
    super.actions,
    required VoidCallback super.onMenuPressed,
    super.showLanguageSwitcher = true,
  }) : super(automaticallyImplyLeading: false);
}

class BackAppBar extends CustomAppBar {
  const BackAppBar({
    super.key,
    required String super.title,
    super.subtitle,
    super.actions,
    super.onBackPressed,
    super.showLanguageSwitcher,
  });
}
