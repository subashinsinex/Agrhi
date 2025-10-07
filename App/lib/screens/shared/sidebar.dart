import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/login_screen.dart';
import '../../utils/colors.dart';
import '../../src/services/language_service.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 16,
      child: Column(
        children: [
          // Header with gradient and logo
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
            child: Row(
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
                  child: // Inside the AppSidebar header Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Agrhi', // App name - no translation needed
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // Add translation to Smart Farming subtitle
                      FutureBuilder<String>(
                        future: Provider.of<LanguageService>(
                          context,
                          listen: false,
                        ).translate('Smart Farm App'),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? 'Smart Farm App',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ],
                  ),
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
                  title: 'Dashboard',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.medical_services_outlined,
                  title: 'Plant Doctor',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.biotech_outlined,
                  title: 'Disease Detection',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.analytics_outlined,
                  title: 'Analytics',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.grass_outlined,
                  title: 'Soil Health',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.wb_sunny_outlined,
                  title: 'Weather',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.attach_money_outlined,
                  title: 'Market Prices',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(thickness: 1),
                ),

                _buildMenuTile(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    // Add navigation to Settings screen when available
                  },
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.pop(context);
                    // Add navigation to Help & Support screen when available
                  },
                ),
              ],
            ),
          ),

          // Logout button at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: _buildMenuTile(
              context,
              icon: Icons.logout,
              title: 'Logout',
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
    final languageService = Provider.of<LanguageService>(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: FutureBuilder<String>(
        future: languageService.translate(title),
        builder: (context, snapshot) {
          return ListTile(
            leading: Icon(
              icon,
              color: isDestructive
                  ? AppColors.errorColor
                  : AppColors.textSecondary,
              size: 24,
            ),
            title: Text(
              snapshot.data ?? title,
              style: TextStyle(
                color: isDestructive
                    ? AppColors.errorColor
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            onTap: onTap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            horizontalTitleGap: 16,
            hoverColor: AppColors.primaryGreen.withOpacity(0.1),
            splashColor: AppColors.primaryGreen.withOpacity(0.2),
          );
        },
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return FutureBuilder<List<String>>(
          future: Future.wait([
            languageService.translate('Confirm Logout'),
            languageService.translate('Are you sure you want to log out?'),
            languageService.translate('Cancel'),
            languageService.translate('Logout'),
            languageService.translate('Logged out successfully'),
          ]),
          builder: (context, snapshot) {
            final translations =
                snapshot.data ??
                [
                  'Confirm Logout',
                  'Are you sure you want to log out?',
                  'Cancel',
                  'Logout',
                  'Logged out successfully',
                ];

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
                translations[0],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              content: Text(
                translations[1],
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                          translations[2],
                          style: const TextStyle(
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
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(translations[4])),
                                ],
                              ),
                              backgroundColor: AppColors.successColor,
                              duration: const Duration(seconds: 3),
                              behavior: SnackBarBehavior.floating,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(10),
                                ),
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
                          translations[3],
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
      },
    );
  }
}
