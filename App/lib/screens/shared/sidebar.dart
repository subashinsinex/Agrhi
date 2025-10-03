import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import '../../utils/colors.dart';
import '../../flutter_gen/gen_l10n/app_localizations.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context); // ✅ Get translations

    return Drawer(
      elevation: 16,
      child: Column(
        children: [
          // Enhanced Header with gradient and profile info
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen,
                  AppColors.primaryGreen.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.appTitle,
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            l10n.appSubtitle,
                            style: TextStyle(
                              color: AppColors.textWhite.withOpacity(0.8),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow
                                .ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildMenuTile(
                  context,
                  icon: Icons.home_outlined,
                  title: l10n.dashboard,
                  onTap: () => Navigator.pop(context),
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.medical_services_outlined,
                  title: l10n.plantDoctor, 
                  onTap: () => _navigateToPage(
                    context,
                    PlaceholderPage(
                      title: l10n.plantDoctor,
                      icon: Icons.medical_services,
                    ),
                  ),
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.biotech_outlined,
                  title: l10n.diseaseDetection, 
                  onTap: () => _navigateToPage(
                    context,
                    PlaceholderPage(
                      title: l10n.diseaseDetection,
                      icon: Icons.biotech,
                    ),
                  ),
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.analytics_outlined,
                  title: l10n.analytics,
                  onTap: () => _navigateToPage(
                    context,
                    PlaceholderPage(
                      title: l10n.analytics,
                      icon: Icons.analytics,
                    ),
                  ),
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.grass_outlined,
                  title: l10n.soilHealth, 
                  onTap: () => _navigateToPage(
                    context,
                    PlaceholderPage(
                      title: l10n.soilHealth,
                      icon: Icons.grass,
                    ),
                  ),
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.wb_sunny_outlined,
                  title: l10n.weather,
                  onTap: () => _navigateToPage(
                    context,
                    PlaceholderPage(
                      title: l10n.weather,
                      icon: Icons.wb_sunny,
                    ),
                  ),
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.attach_money_outlined,
                  title: l10n.marketPrices,
                  onTap: () => _navigateToPage(
                    context,
                    PlaceholderPage(
                      title: l10n.marketPrices,
                      icon: Icons.attach_money,
                    ),
                  ),
                ),

                // Divider with spacing
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(thickness: 1),
                ),

                _buildMenuTile(
                  context,
                  icon: Icons.settings_outlined,
                  title: l10n.settings,
                  onTap: () => _navigateToPage(
                    context,
                    PlaceholderPage(
                      title: l10n.settings,
                      icon: Icons.settings,
                    ),
                  ),
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.help_outline,
                  title: l10n.helpSupport,
                  onTap: () => _navigateToPage(
                    context,
                    PlaceholderPage(
                      title: l10n.helpSupport,
                      icon: Icons.help_outline,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom section with logout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: _buildMenuTile(
              context,
              icon: Icons.logout,
              title: l10n.logout,
              isDestructive: true,
              onTap: () => _showLogoutConfirmation(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? AppColors.errorColor : AppColors.textSecondary,
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? AppColors.errorColor : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        horizontalTitleGap: 16,
        hoverColor: AppColors.primaryGreen.withOpacity(0.1),
        splashColor: AppColors.primaryGreen.withOpacity(0.2),
      ),
    );
  }

  void _navigateToPage(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  void _showLogoutConfirmation(BuildContext context) {
    final l10n = AppLocalizations.of(context); 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 24,
          backgroundColor: AppColors.backgroundColor,
          icon: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.errorColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.logout_rounded,
              color: AppColors.errorColor,
              size: 32,
            ),
          ),
          title: Text(
            l10n.confirmLogout, 
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            l10n.logoutMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(l10n.loggedOutSuccessfully),
                            ],
                          ),
                          backgroundColor: AppColors.successColor,
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );

                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorColor,
                      foregroundColor: AppColors.textWhite,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      l10n.logout,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        );
      },
    );
  }
}

// Enhanced Placeholder Page with translations
class PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const PlaceholderPage({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.textWhite,
        elevation: 8,
        shadowColor: AppColors.shadowColor,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(icon, size: 80, color: AppColors.primaryGreen),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.comingSoon,
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.featureUnderDevelopment,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(l10n.backToDashboard),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.textWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
