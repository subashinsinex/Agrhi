import 'package:flutter/material.dart';
import '../../../utils/colors.dart';
import '../../../flutter_gen/gen_l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);

    return AppBar(
      title: _buildTitle(context, l10n),
      actions: _buildActions(context, l10n),
      leading: leading ?? _buildLeading(context, l10n),
      automaticallyImplyLeading: false,
      backgroundColor: backgroundColor ?? AppColors.appBarBackground,
      foregroundColor: foregroundColor ?? AppColors.textWhite,
      elevation: elevation ?? 8,
      shadowColor: AppColors.shadowColor,
      scrolledUnderElevation: elevation ?? 8,
      centerTitle: centerTitle,
    );
  }

  List<Widget>? _buildActions(BuildContext context, AppLocalizations l10n) {
    final actionsList = <Widget>[];

    // Add language switcher first if enabled
    if (showLanguageSwitcher) {
      actionsList.add(const LanguageSwitcher(showAsIcon: true));
    }

    // Add custom actions
    if (actions != null) {
      actionsList.addAll(actions!);
    }

    return actionsList.isEmpty ? null : actionsList;
  }

  Widget? _buildTitle(BuildContext context, AppLocalizations l10n) {
    if (title == null && subtitle == null) return null;

    // ✅ Fixed: Better null handling
    String? translatedTitle;
    String? translatedSubtitle;

    // Handle title translation
    if (title != null) {
      switch (title) {
        case 'Welcome':
          translatedTitle = l10n.welcome;
          break;
        case 'Profile':
          translatedTitle = 'Profile'; // Add to ARB files if needed
          break;
        default:
          translatedTitle = title;
      }
    }

    // Handle subtitle translation
    if (subtitle != null) {
      switch (subtitle) {
        case 'Enjoy our Services':
          translatedSubtitle = l10n.enjoyServices;
          break;
        default:
          translatedSubtitle = subtitle;
      }
    }

    // ✅ Fixed: Proper null checking
    if (translatedSubtitle != null && translatedTitle != null) {
      return Column(
        crossAxisAlignment: centerTitle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            translatedTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: foregroundColor ?? AppColors.textWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            translatedSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: (foregroundColor ?? AppColors.textWhite).withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // ✅ Fixed: Handle case with only title
    if (translatedTitle != null) {
      return Text(
        translatedTitle,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: foregroundColor ?? AppColors.textWhite,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return null;
  }

  Widget? _buildLeading(BuildContext context, AppLocalizations l10n) {
    if (onMenuPressed != null) {
      return IconButton(
        icon: Icon(Icons.menu, color: foregroundColor ?? AppColors.textWhite),
        onPressed: onMenuPressed,
        tooltip: 'Menu',
      );
    } else if (onBackPressed != null) {
      return IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: foregroundColor ?? AppColors.textWhite,
        ),
        onPressed: onBackPressed,
        tooltip: 'Back',
      );
    } else if (automaticallyImplyLeading && Navigator.of(context).canPop()) {
      return IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: foregroundColor ?? AppColors.textWhite,
        ),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
      );
    }
    return null;
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ✅ Updated DashboardAppBar with language switcher
class DashboardAppBar extends CustomAppBar {
  const DashboardAppBar({super.key, super.actions})
    : super(
        title: 'Welcome',
        subtitle: 'Enjoy our Services',
        automaticallyImplyLeading: false,
        onMenuPressed: null,
        showLanguageSwitcher: false,
      );

  const DashboardAppBar.withMenu({
    super.key,
    required VoidCallback onMenuPressed,
    List<Widget>? additionalActions,
  }) : super(
         title: 'Welcome',
         subtitle: 'Enjoy our Services',
         automaticallyImplyLeading: false,
         onMenuPressed: onMenuPressed,
         showLanguageSwitcher: true,
         actions: additionalActions,
       );
}

class FeatureAppBar extends CustomAppBar {
  const FeatureAppBar({
    super.key,
    required String featureName,
    super.actions,
    super.onBackPressed,
    super.showLanguageSwitcher,
  }) : super(
         title: featureName,
         centerTitle: true,
       );
}

class ProfileAppBar extends CustomAppBar {
  final String userName;

  const ProfileAppBar({
    super.key,
    required this.userName,
    super.actions,
    super.onBackPressed,
    super.showLanguageSwitcher,
  }) : super(
         title: 'Profile',
         subtitle: 'Hello, $userName',
       );
}

class MenuAppBar extends CustomAppBar {
  const MenuAppBar({
    super.key,
    required String super.title,
    super.subtitle,
    super.actions,
    required VoidCallback super.onMenuPressed,
    super.showLanguageSwitcher = true,
  }) : super(
         automaticallyImplyLeading: false,
       );
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
