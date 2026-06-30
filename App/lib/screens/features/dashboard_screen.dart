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
import '../shared/language_switcher.dart';
import '../components/weather_card.dart';
import '../components/upcoming_notification_card.dart';
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
import '../../screens/features/farm_store/setup_screen.dart';
import '../../screens/features/farm_store/farm_product_screen.dart';
import '../../screens/features/market_place/market_place_screen.dart';
import '../features/about_screen.dart';
import '../features/community/community_screen.dart';
import '../features/ai_chat/ai_chat_screen.dart';
import '../../src/services/reminders_manager.dart';
import '../../src/services/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? userData;
  bool _isLoadingProfile = true;
  bool _isRefreshingDashboard = false;

  int _weatherRefreshKey = 0;
  int _notificationRefreshKey = 0;
  int _profileRefreshKey = 0;
  int _featuresRefreshKey = 0;

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
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshDashboard();
      await _preloadDashboardPhrases();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDashboard();
    }
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshingDashboard) return;

    if (mounted) {
      setState(() {
        _isRefreshingDashboard = true;
      });
    } else {
      _isRefreshingDashboard = true;
    }

    try {
      await _loadUserData();

      if (!mounted) return;

      setState(() {
        _weatherRefreshKey++;
        _notificationRefreshKey++;
        _profileRefreshKey++;
        _featuresRefreshKey++;
      });
    } catch (e, stackTrace) {
      debugPrint('DASHBOARD_REFRESH_ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingDashboard = false;
        });
      } else {
        _isRefreshingDashboard = false;
      }
    }
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
      'Model Library',
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
      'My Produce',
      'Map',
      'About Us',
      'This feature requires internet connection',
      'Language',
      'AGRHI Assistant',
      'Community',
      'Upcoming Notifications',
      'AI Chat',
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
        if (mounted) {
          setState(() {
            userData = null;
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

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
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _navigateWithOnlineCheck(Widget screen) {
    final connectivityManager = context.read<ConnectivityManager>();

    if (connectivityManager.isOnline) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    } else {
      _showOfflineWarning();
    }
  }

  Future<void> _navigateToFarmStore() async {
    final connectivityManager = context.read<ConnectivityManager>();

    if (!connectivityManager.isOnline) {
      _showOfflineWarning();
      return;
    }

    try {
      final hasShopPlace = await _storage.read(key: 'has_shop_place');

      if (hasShopPlace == 'true') {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FarmProductsScreen()),
          );
        }
      } else {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SetupScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error reading shop place flag: $e');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SetupScreen()),
        );
      }
    }
  }

  List<FeatureItem> _buildFeatures() {
    if (userData == null) return [];

    final category = userData!['category']?.toString().toLowerCase() ?? '';
    final isRetailer = category == 'retailer';
    final isAdmin = category == 'admin';
    final isFarmer = category == 'farmer';
    final isConsumer = category == 'consumer';

    return [
      FeatureItem(
        title: 'Plant Doctor',
        icon: Icons.biotech,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DetectDiseaseScreen()),
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
        title: 'Marketplace',
        icon: Icons.shopping_cart,
        onTap: () => _navigateWithOnlineCheck(const MarketplaceScreen()),
      ),
      if (!isConsumer)
        FeatureItem(
          title: 'Crop Care',
          icon: Icons.agriculture,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CropCareScreen()),
          ),
        ),
      if (!isConsumer)
        FeatureItem(
          title: 'Crop History',
          icon: Icons.history_edu,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CropHistoryScreen()),
          ),
        ),
      if (isFarmer || isAdmin)
        FeatureItem(
          title: 'Farm Store',
          icon: Icons.inventory_2,
          onTap: () => _navigateToFarmStore(),
        ),
      FeatureItem(
        icon: Icons.map,
        title: 'Map',
        onTap: () => _navigateWithOnlineCheck(const MapScreen()),
      ),
      if (isRetailer || isAdmin)
        FeatureItem(
          title: 'My Shops',
          icon: Icons.store,
          onTap: () => _navigateWithOnlineCheck(const ShopsListScreen()),
        ),
      FeatureItem(
        title: 'Subsidy',
        icon: Icons.monetization_on,
        onTap: () => _navigateWithOnlineCheck(const SubsidyScreen()),
      ),

      /*
      --- For Second Version
      FeatureItem(
        title: 'AI Assistant',
        icon: Icons.smart_toy_outlined,
        onTap: () => _navigateWithOnlineCheck(const AiChatScreen()),
      ),
      FeatureItem(
        title: 'Community',
        icon: Icons.people_alt_outlined,
        onTap: () => _navigateWithOnlineCheck(const CommunityScreen()),
      ),
      */

    ];
  }

  Future<void> _performManualSync() async {
    final connectivityManager = context.read<ConnectivityManager>();

    if (!connectivityManager.isOnline) {
      _showSnackBar(
        'No internet connection',
        AppColors.errorColor,
        duration: 3,
      );
      return;
    }

    if (connectivityManager.isSyncing) {
      _showSnackBar('Sync in progress...', AppColors.infoColor, duration: 2);
      return;
    }

    _showSnackBar(
      'Syncing data...',
      AppColors.infoColor,
      duration: 2,
      showProgress: true,
    );

    final result = await connectivityManager.performManualSync();

    if (result['success']) {
      _showSyncSuccessSnackBar(result);
      await _refreshDashboard();
    } else {
      _showSnackBar(
        result['error'] ?? 'Sync failed. Please try again.',
        AppColors.errorColor,
        duration: 3,
      );
    }
  }

  void _showSnackBar(
    String message,
    Color backgroundColor, {
    int duration = 3,
    bool showProgress = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (showProgress)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            if (showProgress) const SizedBox(width: 10),
            Expanded(
              child: SmartReTranslator(
                text: message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        duration: Duration(seconds: duration),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSyncSuccessSnackBar(Map<String, dynamic> result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const SmartReTranslator(
          text: '✅ Full sync completed',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.successColor,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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

      await RemindersManager.instance.clearAllNotificationsOnLogout();
      await NotificationService.debugPendingNotifications();

      await db.transaction((txn) async {
        await txn.delete('disease_analysis_results');
        await txn.delete('cropreminders');
        await txn.delete('farm_soiltypes');
        await txn.delete('farm_irrigations');
        await txn.delete('farm_watersources');
        await txn.delete('images');
        await txn.delete('usercrops');
        await txn.delete('farms');
      });

      debugPrint('✅ Database tables cleared');

      debugPrint('🗑️ Deleting disease images...');
      await _deleteDirectoryIfExists(
        await getApplicationDocumentsDirectory(),
        'disease_images',
      );
      await _deleteDirectoryIfExists(
        await getApplicationSupportDirectory(),
        'disease_images',
      );

      debugPrint('🗑️ Clearing app cache...');
      await _clearCacheDirectory();

      debugPrint('🎉 Background cleanup complete');
    } catch (e, stackTrace) {
      debugPrint('❌ Error during background cleanup: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _deleteDirectoryIfExists(
    Directory baseDir,
    String subPath,
  ) async {
    try {
      final dir = Directory('${baseDir.path}/$subPath');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        debugPrint('✅ Deleted: ${dir.path}');
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting $subPath: $e');
    }
  }

  Future<void> _clearCacheDirectory() async {
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
                        onPressed: () async {
                          final navigator = Navigator.of(
                            context,
                            rootNavigator: true,
                          );

                          navigator.pop();

                          try {
                            await _performBackgroundCleanup().timeout(
                              const Duration(seconds: 8),
                              onTimeout: () {
                                debugPrint('LOGOUT_STEP: cleanup timeout');
                              },
                            );
                          } catch (e, stackTrace) {
                            debugPrint('LOGOUT_STEP: cleanup failed $e');
                            debugPrintStack(stackTrace: stackTrace);
                          }

                          if (!mounted) return;

                          await navigator.pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
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

  void _showLanguageSelectionDialog() {
    LanguageSwitcher.showBottomSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguageCode = Provider.of<LanguageService>(
      context,
    ).currentLocale.languageCode;
    final bool showDashboardSkeleton =
        _isLoadingProfile || _isRefreshingDashboard;

    return Scaffold(
      appBar: DashboardAppBar.withSettings(
        onSyncPressed: _performManualSync,
        onHelpPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FeedbackScreen()),
          );
        },
        onAboutPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AboutScreen()),
          );
        },
        onLogoutPressed: _showLogoutConfirmation,
        onLanguagePressed: _showLanguageSelectionDialog,
        isSyncing: context.watch<ConnectivityManager>().isSyncing,
      ),
      backgroundColor: AppColors.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: AppColors.primaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 10),

              showDashboardSkeleton
                  ? _buildWeatherSkeleton()
                  : WeatherCard(
                      key: ValueKey(
                        'weather_${currentLanguageCode}_$_weatherRefreshKey',
                      ),
                      useDeviceLocation: true,
                    ),

              const SizedBox(height: 5),

              showDashboardSkeleton
                  ? _buildUpcomingNotificationSkeleton()
                  : UpcomingNotificationCard(
                      key: ValueKey(
                        'upcoming_notifications_$_notificationRefreshKey',
                      ),
                      backgroundColor: AppColors.primaryGreen,
                      daysAhead: 30,
                    ),

              const SizedBox(height: 18),
              _buildSectionHeader('Profile', Icons.person_outline),
              const SizedBox(height: 12),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: showDashboardSkeleton
                    ? _buildProfileSkeleton()
                    : ProfileCard(
                        key: ValueKey('profile_card_$_profileRefreshKey'),
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
                          ).then((_) => _refreshDashboard());
                        },
                      ),
              ),

              const SizedBox(height: 18),
              _buildSectionHeader('Features', Icons.grid_view_rounded),
              const SizedBox(height: 12),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: showDashboardSkeleton
                    ? _buildFeaturesSkeleton()
                    : DirectFeatureGrid(
                        key: ValueKey(
                          '${currentLanguageCode}_${userData?['category'] ?? "none"}_$_featuresRefreshKey',
                        ),
                        features: _buildFeatures(),
                        crossAxisCount: 3,
                        childAspectRatio: 0.9,
                        spacing: 12,
                      ),
              ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherSkeleton() {
    return Container(
      key: const ValueKey('weather_skeleton'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGreen.withOpacity(0.95),
                AppColors.primaryGreen.withOpacity(0.82),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.28),
                    width: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 110,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 150,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 70,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 55,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.22),
                    width: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingNotificationSkeleton() {
    return Container(
      key: const ValueKey('notification_skeleton'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 7),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGreen.withOpacity(0.95),
                AppColors.primaryGreen.withOpacity(0.82),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.28),
                    width: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 90,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 130,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 105,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.22),
                    width: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryGreen),
          ),
          const SizedBox(width: 10),
          SmartReTranslator(
            text: title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSkeleton() {
    return Container(
      key: const ValueKey('profile_skeleton'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGreen.withOpacity(0.90),
                AppColors.primaryGreen.withOpacity(0.78),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1.4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.28),
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        height: 13,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 78,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.26),
                            width: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.24),
                      width: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesSkeleton() {
    return Padding(
      key: const ValueKey('features_skeleton'),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withOpacity(0.88),
                  AppColors.primaryGreen,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withOpacity(0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.24),
                      width: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 58,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 48,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(6),
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

class DirectFeatureGrid extends StatelessWidget {
  final List<FeatureItem> features;
  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;

  const DirectFeatureGrid({
    super.key,
    required this.features,
    this.crossAxisCount = 3,
    this.childAspectRatio = 0.9,
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
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: feature.onTap,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryGreen.withOpacity(0.9),
                      AppColors.primaryGreen,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(feature.icon, size: 32, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SmartReTranslator(
                        key: ValueKey('feature_${feature.title}_$index'),
                        text: feature.title,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
