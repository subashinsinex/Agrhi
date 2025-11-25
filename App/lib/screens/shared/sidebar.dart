import 'package:agrhi/screens/features/disease_detection_screen.dart';
import 'package:agrhi/screens/features/disease_history_screen.dart';
import 'package:agrhi/screens/features/subsidy_screen.dart';
import '../../src/database/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../auth/login_screen.dart';
import '../../utils/colors.dart';
import '../../src/services/language_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../features/feedback_screen.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  // ⭐ MODIFIED: Background cleanup (runs after navigation)
  Future<void> _performBackgroundCleanup() async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
        synchronizable: false,
      ),
    );

    try {
      debugPrint('🗑️ Starting background cleanup...');

      // 1. Delete secure storage
      debugPrint('🗑️ Clearing secure storage...');
      await storage.deleteAll();
      debugPrint('✅ Secure storage cleared');

      // 2. Clear user-specific database tables
      debugPrint('🗑️ Clearing database tables...');
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        await txn.delete('disease_analysis_results');
        await txn.delete('images');
        await txn.delete('usercrops');
        await txn.delete('farms');
      });

      debugPrint('✅ Database tables cleared');

      // 3. Delete disease_images directory
      debugPrint('🗑️ Deleting disease images...');
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final docImagesDir = Directory('${appDocDir.path}/disease_images');

        if (await docImagesDir.exists()) {
          await docImagesDir.delete(recursive: true);
          debugPrint('✅ Documents disease images deleted');
        }

        final appSupportDir = await getApplicationSupportDirectory();
        final supportImagesDir = Directory(
          '${appSupportDir.path}/disease_images',
        );

        if (await supportImagesDir.exists()) {
          await supportImagesDir.delete(recursive: true);
          debugPrint('✅ Support disease images deleted');
        }
      } catch (e) {
        debugPrint('⚠️ Error deleting disease images: $e');
      }

      // 4. Clear cache contents
      debugPrint('🗑️ Clearing app cache...');
      try {
        final cacheDir = await getTemporaryDirectory();
        if (await cacheDir.exists()) {
          await for (var entity in cacheDir.list()) {
            try {
              if (entity is File) {
                await entity.delete();
              } else if (entity is Directory) {
                await entity.delete(recursive: true);
              }
            } catch (e) {
              debugPrint('⚠️ Failed to delete: ${entity.path}');
            }
          }
          debugPrint('✅ App cache cleared');
        }
      } catch (e) {
        debugPrint('⚠️ Error clearing cache: $e');
      }

      debugPrint('🎉 Background cleanup complete');
    } catch (e, stackTrace) {
      debugPrint('❌ Error during background cleanup: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 16,
      backgroundColor: AppColors.backgroundColor,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Agrhi',
                        style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                  icon: Icons.biotech_outlined,
                  title: 'Plant Doctor',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DetectDiseaseScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.history,
                  title: 'Detection History',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DiseaseHistoryScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.monetization_on,
                  title: 'Subsidy',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SubsidyScreen(),
                      ),
                    );
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
                  },
                ),
                _buildMenuTile(
                  context,
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FeedbackScreen(),
                      ),
                    );
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
          ]),
          builder: (context, snapshot) {
            final translations =
                snapshot.data ??
                [
                  'Confirm Logout',
                  'Are you sure you want to log out?',
                  'Cancel',
                  'Logout',
                ];

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 24,
              backgroundColor: AppColors.primaryWhite,
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
                          // ⭐ STEP 1: Close dialog
                          Navigator.pop(dialogContext);

                          // ⭐ STEP 2: Close drawer
                          Navigator.pop(context);

                          // ⭐ STEP 3: Navigate to login IMMEDIATELY
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (Route<dynamic> route) => false,
                          );

                          // ⭐ STEP 4: Run cleanup in background (non-blocking)
                          _performBackgroundCleanup();
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
