import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/colors.dart';
import '../../../src/services/language_service.dart';
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
      elevation: elevation ?? 8,
      shadowColor: AppColors.shadowColor,
      scrolledUnderElevation: elevation ?? 8,
      centerTitle: centerTitle,
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
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          FutureBuilder<String>(
            future: languageService.translate(subtitle!),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: (foregroundColor ?? AppColors.textWhite).withOpacity(
                    0.8,
                  ),
                  fontWeight: FontWeight.w500,
                ),
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
              fontWeight: FontWeight.bold,
            ),
          );
        },
      );
    }

    return null;
  }

  Widget? _buildLeading(BuildContext context) {
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
