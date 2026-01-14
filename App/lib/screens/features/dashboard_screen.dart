import '/screens/features/crop_care/crop_history_screen.dart';
import '/screens/features/disease_detection/model_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../shared/custom_app_bar.dart';
import '../../utils/colors.dart';
import '../../src/services/language_service.dart';
import '../../src/services/connectivity_manager.dart';
import '../shared/smart_retranslator.dart';
import '../components/weather_card.dart';
import '../components/profile_card.dart';
import '../components/feature_grid.dart';
import 'disease_detection/disease_detection_screen.dart';
import 'subsidy_screen.dart';
import 'crop_care/crop_care_screen.dart';
import 'disease_detection/disease_history_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../src/database/database_helper.dart';
import 'feedback_screen.dart';
import 'map.dart';
import '../auth/login_screen.dart';
import 'profile_screen.dart';
import './retail_management/shops_screen.dart';
import '../../src/services/retail_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? userData;
  bool _isLoadingProfile = true;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _preloadDashboardPhrases();
    });
  }

  Future<void> _preloadDashboardPhrases() async {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    await languageService.preloadTexts([
      'Profile',
      'Guest User',
      'Features',
      'Crop Care',
      'Plant Doctor',
      'Subsidy',
      'Crop History',
      'Help & Support',
      'Model Manager',
      'Detection History',
      'Notifications',
      'Notifications feature coming soon!',
      'Sync',
      'Syncing',
      'Sync in progress...',
      '✅ Sync complete!',
      'Sync complete',
      'Sync finished with some issues',
      'Sync failed. Please try again.',
      'Session expired. Please log in again.',
      'Authentication required. Please log in.',
      'Syncing data...',
      'Upload',
      'Downloaded',
      'Images',
      'analyses',
      'Catalogs',
      'updated',
      'Farms',
      'Crops',
      'History',
      'Settings',
      'Logout',
      'Confirm Logout',
      'Are you sure you want to log out?',
      'Cancel',
      'No internet connection',
      'My Shops',
      'This feature requires internet connection', // ✅ ADD
    ], highPriority: true);
  }

  Future<String?> _readWithRetry(String key, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final value = await _storage.read(key: key);
        if (value != null && value.isNotEmpty) {
          return value;
        }
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
        }
      } catch (e) {
        if (i == maxRetries - 1) {
          debugPrint('Storage read failed for $key: $e');
          rethrow;
        }
      }
    }
    return null;
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);

    try {
      final profileJson = await _readWithRetry('user_profile');
      final profileImagePath = await _readWithRetry('profile_image_local_path');

      if (profileJson != null) {
        final profile = jsonDecode(profileJson) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            userData = {
              'name': profile['name'] ?? 'Guest User',
              'email': profile['email'],
              'phone': profile['phone_number'],
              'category': profile['user_category'],
              'address': profile['address'],
              'email_verified': profile['email_verified'] ?? false,
              'profile_image_path': profileImagePath,
            };
            _isLoadingProfile = false;
          });
        }
      } else {
        debugPrint('User profile not found in storage');
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  // ✅ NEW: Show offline warning
  void _showOfflineWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const SmartReTranslator(
          text: 'This feature requires internet connection',
          style: TextStyle(color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.errorColor,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  // ✅ NEW: Navigate with online check
  void _navigateWithOnlineCheck(Widget screen) {
    final connectivityManager = context.read<ConnectivityManager>();

    if (connectivityManager.isOnline) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    } else {
      _showOfflineWarning();
    }
  }

  Future<void> _performManualSync() async {
    final connectivityManager = context.read<ConnectivityManager>();

    if (!connectivityManager.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const SmartReTranslator(
            text: 'No internet connection',
            style: TextStyle(color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (connectivityManager.isSyncing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const SmartReTranslator(
            text: 'Sync in progress...',
            style: TextStyle(color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.infoColor,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: SmartReTranslator(
                text: 'Syncing data...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.infoColor,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final result = await connectivityManager.performManualSync();

    if (result['success']) {
      final diseaseSync = result['disease_sync'] as Map<String, dynamic>?;
      final cropCareSync = result['crop_care_sync'] as Map<String, dynamic>?;

      int catalogsUpdated = 0;
      int uploaded = 0;
      int downloaded = 0;
      int imagesUploaded = 0;
      int farmsUploaded = 0;
      int cropsUploaded = 0;
      int historyDownloaded = 0;

      if (diseaseSync != null && (diseaseSync['success'] ?? false)) {
        final catalogsResult = diseaseSync['catalogs'] as Map<String, dynamic>?;
        final twoWayResult =
            diseaseSync['two_way_sync'] as Map<String, dynamic>?;

        catalogsUpdated = (catalogsResult?['updated'] as int?) ?? 0;
        uploaded = (twoWayResult?['upload']?['upload'] as int?) ?? 0;
        downloaded = (twoWayResult?['download']?['downloaded'] as int?) ?? 0;
        imagesUploaded = (twoWayResult?['images']?['upload'] as int?) ?? 0;
      }

      if (cropCareSync != null && (cropCareSync['success'] ?? false)) {
        final sync = cropCareSync['sync'] as Map<String, dynamic>?;
        if (sync != null) {
          farmsUploaded = sync['farmUpload']?['uploaded'] ?? 0;
          cropsUploaded = sync['cropUpload']?['uploaded'] ?? 0;
          historyDownloaded = sync['historyDownload']?['downloaded'] ?? 0;
        }
      }

      messenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SmartReTranslator(
                text: '✅ Sync complete!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              if (result['disease_success'] == true)
                SmartReTranslator(
                  text:
                      'Upload $uploaded, Downloaded $downloaded, Images $imagesUploaded, Catalogs $catalogsUpdated',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              if (result['disease_success'] == true &&
                  result['crop_care_success'] == true)
                const SizedBox(height: 3),
              if (result['crop_care_success'] == true)
                SmartReTranslator(
                  text:
                      'Farms $farmsUploaded, Crops $cropsUploaded, History $historyDownloaded',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.successColor,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: SmartReTranslator(
            text: result['error'] ?? 'Sync failed. Please try again.',
            style: const TextStyle(color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorColor,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _performBackgroundCleanup() async {
    try {
      debugPrint('🗑️ Starting background cleanup...');

      debugPrint('🗑️ Clearing secure storage...');
      await _storage.deleteAll();

      await RetailService.clearCache();

      debugPrint('✅ Secure storage cleared');

      debugPrint('🗑️ Clearing database tables...');
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        await txn.delete('disease_analysis_results');
        await txn.delete('farm_soiltypes');
        await txn.delete('farm_irrigations');
        await txn.delete('farm_watersources');
        await txn.delete('images');
        await txn.delete('usercrops');
        await txn.delete('farms');
      });

      debugPrint('✅ Database tables cleared');

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

  void _showLogoutConfirmation() {
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
                          Navigator.pop(dialogContext);
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (Route<dynamic> route) => false,
                          );
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

  @override
  Widget build(BuildContext context) {
    bool isRetailer =
        (userData?['category']?.toString().toLowerCase() == 'retailer');

    final features = [
      FeatureItem(
        title: 'Crop Care',
        icon: Icons.agriculture,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CropCareScreen()),
        ),
      ),
      FeatureItem(
        title: 'Plant Doctor',
        icon: Icons.biotech,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DetectDiseaseScreen()),
        ),
      ),
      FeatureItem(
        title: 'Subsidy',
        icon: Icons.monetization_on,
        onTap: () => _navigateWithOnlineCheck(const SubsidyScreen()),
      ),
      FeatureItem(
        title: 'Crop History',
        icon: Icons.history_edu,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CropHistoryScreen()),
        ),
      ),
      FeatureItem(
        title: 'Detection History',
        icon: Icons.history,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DiseaseHistoryScreen()),
        ),
      ),
      FeatureItem(
        icon: Icons.download,
        title: 'Model Library',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ModelManagerScreen()),
        ),
      ),
      FeatureItem(
        icon: Icons.map,
        title: 'Map',
        onTap: () => _navigateWithOnlineCheck(const MapScreen()),
      ),
      if (isRetailer)
        FeatureItem(
          title: 'My Shops',
          icon: Icons.store,
          onTap: () => _navigateWithOnlineCheck(const ShopsListScreen()),
        ),
    ];

    return Scaffold(
      appBar: DashboardAppBar.withSettings(
        onSyncPressed: () => _performManualSync(),
        onHelpPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FeedbackScreen()),
          );
        },
        onLogoutPressed: _showLogoutConfirmation,
        isSyncing: context.watch<ConnectivityManager>().isSyncing,
      ),
      backgroundColor: AppColors.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 25.0),
            child: Column(
              children: [
                WeatherCard(
                  key: ValueKey(
                    'weather_${Provider.of<LanguageService>(context).currentLocale.languageCode}',
                  ),
                  useDeviceLocation: true,
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SmartReTranslator(
                      text: 'Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoadingProfile
                      ? _buildProfileSkeleton()
                      : ProfileCard(
                          key: const ValueKey('profile_card'),
                          name: userData?['name'] ?? 'Guest User',
                          email: userData?['email'],
                          category: userData?['category'],
                          emailVerified: userData?['email_verified'] ?? false,
                          profileImagePath: userData?['profile_image_path'],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SmartReTranslator(
                      text: 'Features',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DirectFeatureGrid(
                  key: ValueKey(
                    Provider.of<LanguageService>(
                      context,
                    ).currentLocale.languageCode,
                  ),
                  features: features,
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
                  spacing: 12,
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSkeleton() {
    return Container(
      key: const ValueKey('profile_skeleton'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withOpacity(0.8),
            AppColors.primaryGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                color: AppColors.mediumGreenAccent.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primaryWhite.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 180,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.primaryWhite.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primaryWhite.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryWhite.withOpacity(0.2),
              ),
              child: const SizedBox(width: 18, height: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class DirectFeatureGrid extends StatelessWidget {
  final List<FeatureItem> features;
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;

  const DirectFeatureGrid({
    super.key,
    required this.features,
    this.crossAxisCount = 3,
    this.childAspectRatio = 0.85,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: features.length,
        itemBuilder: (context, index) {
          final feature = features[index];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: feature.onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Card(
                    color: AppColors.primaryGreen,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.all(4),
                    child: Center(
                      child: Icon(
                        feature.icon,
                        size: 36,
                        color: AppColors.primaryWhite,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SmartReTranslator(
                    key: ValueKey('feature_${feature.title}_$index'),
                    text: feature.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
