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
  final bool translateTitle;
  final TabBar? bottom;

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
    this.translateTitle = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    final toolbarHeight = hasSubtitle ? 82.0 : 68.0;

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: toolbarHeight,
      elevation: elevation ?? 0,
      scrolledUnderElevation: 0,
      backgroundColor: backgroundColor ?? Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      titleSpacing: 0,
      leadingWidth: 64,
      leading: leading ?? _buildLeading(context),
      title: _buildTitle(context, hasSubtitle),
      actions: _buildActions(),
      centerTitle: centerTitle,
      bottom: bottom,
    );
  }

  Widget? _buildTitle(BuildContext context, bool hasSubtitle) {
    if (title == null && subtitle == null) return null;

    final textColor = foregroundColor ?? Colors.black;

    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: textColor,
      fontWeight: FontWeight.w700,
      fontSize: 20,
      letterSpacing: -0.2,
      height: 1.1,
    );

    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: textColor.withOpacity(0.72),
      fontWeight: FontWeight.w500,
      fontSize: 12.5,
      height: 1.2,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: centerTitle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (title != null)
          translateTitle
              ? _TranslatedText(text: title!, style: titleStyle, maxLines: 1)
              : Text(
                  title!,
                  style: titleStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
        if (hasSubtitle) ...[
          const SizedBox(height: 4),
          _TranslatedText(text: subtitle!, style: subtitleStyle, maxLines: 1),
        ],
      ],
    );
  }

  Widget? _buildLeading(BuildContext context) {
    if (leading != null) return leading!;

    final iconColor = foregroundColor ?? Colors.black;

    if (onMenuPressed != null) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _CleanIconButton(
          icon: Icons.menu_rounded,
          onPressed: onMenuPressed!,
          tooltip: 'Menu',
          color: iconColor,
        ),
      );
    }

    if (onBackPressed != null ||
        (automaticallyImplyLeading && Navigator.of(context).canPop())) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _CleanIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
          tooltip: 'Back',
          color: iconColor,
        ),
      );
    }

    return null;
  }

  List<Widget>? _buildActions() {
    final items = <Widget>[];

    if (showOnlineStatus) {
      items.add(const _OnlineStatusIconMinimal());
    }

    if (actions != null) {
      items.addAll(actions!);
    }

    if (items.isNotEmpty) {
      items.add(const SizedBox(width: 8));
    }

    return items.isEmpty ? null : items;
  }

  @override
  Size get preferredSize => Size.fromHeight(
    (subtitle != null && subtitle!.trim().isNotEmpty ? 82 : 68) +
        (bottom?.preferredSize.height ?? 0),
  );
}

class _TranslatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;

  const _TranslatedText({
    required this.text,
    this.style,
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
          overflow: TextOverflow.ellipsis,
          maxLines: maxLines ?? 1,
        );
      },
    );
  }
}

class _CleanIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color color;

  const _CleanIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

class AppBarActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color color;

  const AppBarActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlineStatusIconMinimal extends StatelessWidget {
  const _OnlineStatusIconMinimal();

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityManager>(
      builder: (context, connectivityManager, _) {
        final isOnline = connectivityManager.isOnline;
        final isSyncing = connectivityManager.isSyncing;

        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Tooltip(
            message: _getTooltipMessage(isOnline, isSyncing),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: isSyncing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            Colors.blue.shade600,
                          ),
                        ),
                      )
                    : Icon(
                        isOnline
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        size: 19,
                        color: isOnline ? Colors.black : AppColors.errorColor,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getTooltipMessage(bool isOnline, bool isSyncing) {
    if (isSyncing) return 'Syncing data with server...';
    if (isOnline) return 'Connected to internet';
    return 'No internet connection';
  }
}

class BackAppBar extends CustomAppBar {
  const BackAppBar({
    super.key,
    required String super.title,
    super.subtitle,
    super.actions,
    super.onBackPressed,
    super.showOnlineStatus = true,
    super.translateTitle = true,
    super.bottom,
  });
}
