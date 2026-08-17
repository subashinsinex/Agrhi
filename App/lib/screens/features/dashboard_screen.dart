import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../../src/database/database_helper.dart';
import '../../../../src/services/connectivity_manager.dart';
import '../../../../src/services/language_service.dart';
import '../../../../src/services/notification_service.dart';
import '../../../../src/services/reminders_manager.dart';
import '../../../../src/services/retail_service.dart';
import '../../../../utils/colors.dart';
import '../auth/login_screen.dart';
import '../components/feature_grid.dart';
import '../components/profile_card.dart';
import '../components/upcoming_notification_card.dart';
import '../components/weather_card.dart';
import '../features/feedback_screen.dart';
import '../shared/language_switcher.dart';
import '../shared/smart_retranslator.dart';
import 'about_screen.dart';
import 'map.dart';
import 'profile_screen.dart';
import 'retail_management/shops_screen.dart';
import 'crop_care/crop_care_screen.dart';
import 'crop_care/crop_history_screen.dart';
import 'disease_detection/disease_detection_screen.dart';
import 'disease_detection/disease_history_screen.dart';
import 'disease_detection/model_manager_screen.dart';
import 'farm_store/farm_product_screen.dart';
import 'farm_store/setup_screen.dart';
import 'market_place/market_place_screen.dart';
import 'subsidy_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? userData;

  bool isLoadingProfile = true;
  bool isRefreshingDashboard = false;

  final GlobalKey<WeatherCardState> weatherCardKey =
      GlobalKey<WeatherCardState>();

  int notificationRefreshKey = 0;
  int profileRefreshKey = 0;
  int featuresRefreshKey = 0;

  static const storage = FlutterSecureStorage(
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshDashboard();
      preloadDashboardPhrases();
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
      refreshDashboard();
    }
  }

  Future<void> refreshDashboard() async {
    if (isRefreshingDashboard) return;

    if (mounted) {
      setState(() => isRefreshingDashboard = true);
    } else {
      isRefreshingDashboard = true;
    }

    try {
      await loadUserData();

      final weatherState = weatherCardKey.currentState;
      if (weatherState != null) {
        unawaited(
          weatherState.refreshWeather(
            forceRefresh: true,
            showLoaderOnlyIfEmpty: false,
          ),
        );
      }
      if (!mounted) return;

      setState(() {
        notificationRefreshKey++;
        profileRefreshKey++;
        featuresRefreshKey++;
      });
    } catch (e, stackTrace) {
      debugPrint('DASHBOARD_REFRESH_ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() => isRefreshingDashboard = false);
      } else {
        isRefreshingDashboard = false;
      }
    }
  }

  Future<void> preloadDashboardPhrases() async {
    try {
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
        'Sync',
        'Syncing',
        'Sync in progress...',
        'Sync complete!',
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
        'Upcoming Notifications',
        'Good morning',
        'Good afternoon',
        'Good evening',
        'Welcome',
        'Grow Smart, Grow Better',
        'Full sync completed',
      ], highPriority: true);
    } catch (e) {
      debugPrint('Phrase preload failed: $e');
    }
  }

  String? _pickFirstNonEmpty(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return null;

    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;

      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  bool _pickBool(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return false;

    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;

      if (value is bool) return value;

      final text = value.toString().trim().toLowerCase();
      if (text == 'true' || text == '1' || text == 'yes') return true;
      if (text == 'false' || text == '0' || text == 'no') return false;
    }

    return false;
  }

  Future<void> loadUserData() async {
    if (!mounted) return;

    setState(() => isLoadingProfile = true);

    try {
      final allValues = await storage.readAll();

      final profileImagePath =
          allValues['profileimagelocalpath'] ??
          allValues['profile_image_local_path'];

      final profileJson =
          allValues['userprofile'] ??
          allValues['userProfile'] ??
          allValues['profile'] ??
          allValues['userdata'] ??
          allValues['userData'] ??
          allValues['user_profile'];

      Map<String, dynamic> profile = {};

      if (profileJson != null && profileJson.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(profileJson);
          if (decoded is Map<String, dynamic>) {
            profile = decoded;
          }
        } catch (e) {
          debugPrint('Profile JSON decode failed: $e');
        }
      }

      final normalizedProfile = {
        'name':
            _pickFirstNonEmpty(profile, ['name', 'username']) ??
            _pickFirstNonEmpty(allValues, ['name', 'username']),
        'email':
            _pickFirstNonEmpty(profile, ['email']) ??
            _pickFirstNonEmpty(allValues, ['email']),
        'phone':
            _pickFirstNonEmpty(profile, [
              'phonenumber',
              'phone',
              'phone_number',
            ]) ??
            _pickFirstNonEmpty(allValues, [
              'phonenumber',
              'phone',
              'phone_number',
            ]),
        'category':
            _pickFirstNonEmpty(profile, [
              'usercategory',
              'category',
              'user_category',
            ]) ??
            _pickFirstNonEmpty(allValues, [
              'usercategory',
              'category',
              'user_category',
            ]),
        'address':
            _pickFirstNonEmpty(profile, ['address']) ??
            _pickFirstNonEmpty(allValues, ['address']),
        'emailverified':
            _pickBool(profile, ['emailverified', 'email_verified']) ||
            _pickBool(allValues, ['emailverified', 'email_verified']),
      };

      final hasUsefulData =
          (normalizedProfile['name']?.toString().trim().isNotEmpty ?? false) ||
          (normalizedProfile['email']?.toString().trim().isNotEmpty ?? false) ||
          (normalizedProfile['category']?.toString().trim().isNotEmpty ??
              false);

      if (!mounted) return;

      setState(() {
        userData = hasUsefulData
            ? {
                'name': normalizedProfile['name'] ?? 'Guest User',
                'email': normalizedProfile['email'],
                'phone': normalizedProfile['phone'],
                'category': normalizedProfile['category'],
                'address': normalizedProfile['address'],
                'emailverified': normalizedProfile['emailverified'] ?? false,
                'profileimagepath': profileImagePath,
              }
            : {
                'name': 'Guest User',
                'email': null,
                'phone': null,
                'category': null,
                'address': null,
                'emailverified': false,
                'profileimagepath': profileImagePath,
              };

        isLoadingProfile = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading user data: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        userData = {
          'name': 'Guest User',
          'email': null,
          'phone': null,
          'category': null,
          'address': null,
          'emailverified': false,
          'profileimagepath': null,
        };
        isLoadingProfile = false;
      });
    }
  }

  void showOfflineWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const SmartReTranslator(
          text: 'This feature requires internet connection',
          style: TextStyle(color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.errorColor,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void navigateWithOnlineCheck(Widget screen) {
    final connectivityManager = context.read<ConnectivityManager>();
    if (connectivityManager.isOnline) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    } else {
      showOfflineWarning();
    }
  }

  Future<void> navigateToFarmStore() async {
    final connectivityManager = context.read<ConnectivityManager>();
    if (!connectivityManager.isOnline) {
      showOfflineWarning();
      return;
    }

    try {
      final allValues = await storage.readAll();
      final hasShopPlace =
          allValues['hasshopplace'] ?? allValues['has_shop_place'];

      if (!mounted) return;

      if (hasShopPlace == 'true') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FarmProductsScreen()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SetupScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error reading shop place flag: $e');
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SetupScreen()),
      );
    }
  }

  List<FeatureItem> buildFeatures() {
    final category = userData?['category']?.toString().toLowerCase() ?? '';
    final isRetailer = category == 'retailer';
    final isAdmin = category == 'admin';
    final isFarmer = category == 'farmer';
    final isConsumer = category == 'consumer';

    return [
      FeatureItem(
        title: 'Plant Doctor',
        icon: Icons.biotech_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DetectDiseaseScreen()),
        ),
        backgroundColor: const Color(0xFFF8FAF4),
        iconColor: const Color(0xFF2E6B2E),
      ),
      FeatureItem(
        title: 'Detection History',
        icon: Icons.history_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DiseaseHistoryScreen()),
        ),
        backgroundColor: const Color(0xFFF8FAF4),
        iconColor: const Color(0xFF2D7A22),
      ),
      FeatureItem(
        title: 'Model Library',
        icon: Icons.cloud_download_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
        ),
        backgroundColor: const Color(0xFFF4F8FC),
        iconColor: const Color(0xFF236C9E),
      ),
      FeatureItem(
        title: 'Marketplace',
        icon: Icons.shopping_cart_rounded,
        onTap: () => navigateWithOnlineCheck(const MarketplaceScreen()),
        backgroundColor: const Color(0xFFFDF8F1),
        iconColor: const Color(0xFFB6641B),
      ),
      if (!isConsumer)
        FeatureItem(
          title: 'Crop Care',
          icon: Icons.agriculture_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CropCareScreen()),
          ),
          backgroundColor: const Color(0xFFF8FAF4),
          iconColor: const Color(0xFF497F2C),
        ),
      if (!isConsumer)
        FeatureItem(
          title: 'Crop History',
          icon: Icons.menu_book_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CropHistoryScreen()),
          ),
          backgroundColor: const Color(0xFFF9FAF2),
          iconColor: const Color(0xFF7C6A00),
        ),
      FeatureItem(
        title: 'Map',
        icon: Icons.location_on_rounded,
        onTap: () => navigateWithOnlineCheck(const MapScreen()),
        backgroundColor: const Color(0xFFF9FBF6),
        iconColor: const Color(0xFF146A35),
      ),
      if (isRetailer || isAdmin)
        FeatureItem(
          title: 'My Shops',
          icon: Icons.storefront_rounded,
          onTap: () => navigateWithOnlineCheck(const ShopsListScreen()),
          backgroundColor: const Color(0xFFF5F8FC),
          iconColor: const Color(0xFF23689E),
        ),
      if (isFarmer || isAdmin)
        FeatureItem(
          title: 'Farm Store',
          icon: Icons.inventory_2_rounded,
          onTap: navigateToFarmStore,
          backgroundColor: const Color(0xFFF7FAF5),
          iconColor: const Color(0xFF356F31),
        ),
      FeatureItem(
        title: 'Subsidy',
        icon: Icons.account_balance_wallet_rounded,
        onTap: () => navigateWithOnlineCheck(const SubsidyScreen()),
        backgroundColor: const Color(0xFFF9F7FC),
        iconColor: const Color(0xFF6B4594),
      ),
    ];
  }

  Future<void> performManualSync() async {
    final connectivityManager = context.read<ConnectivityManager>();

    if (!connectivityManager.isOnline) {
      showSnackBar('No internet connection', AppColors.errorColor, duration: 3);
      return;
    }

    if (connectivityManager.isSyncing) {
      showSnackBar('Sync in progress...', AppColors.infoColor, duration: 2);
      return;
    }

    showSnackBar(
      'Syncing data...',
      AppColors.infoColor,
      duration: 2,
      showProgress: true,
    );

    final result = await connectivityManager.performManualSync();

    if (result['success'] == true) {
      showSyncSuccessSnackBar();
      await refreshDashboard();
    } else {
      showSnackBar(
        result['error'] ?? 'Sync failed. Please try again.',
        AppColors.errorColor,
        duration: 3,
      );
    }
  }

  void showSnackBar(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void showSyncSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: SmartReTranslator(
          text: 'Full sync completed',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  Future<void> performBackgroundCleanup() async {
    try {
      await storage.deleteAll();
      await RetailService.clearCache();

      final db = await DatabaseHelper.instance.database;
      await RemindersManager.instance.clearAllNotificationsOnLogout();
      await NotificationService.debugPendingNotifications();

      await db.transaction((txn) async {
        await txn.delete('diseaseanalysisresults');
        await txn.delete('cropreminders');
        await txn.delete('farmsoiltypes');
        await txn.delete('farmirrigations');
        await txn.delete('farmwatersources');
        await txn.delete('images');
        await txn.delete('usercrops');
        await txn.delete('farms');
      });

      await deleteDirectoryIfExists(
        await getApplicationDocumentsDirectory(),
        'diseaseimages',
      );
      await deleteDirectoryIfExists(
        await getApplicationSupportDirectory(),
        'diseaseimages',
      );

      await clearCacheDirectory();
    } catch (e, stackTrace) {
      debugPrint('Error during background cleanup: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> deleteDirectoryIfExists(
    Directory baseDir,
    String subPath,
  ) async {
    try {
      final dir = Directory('${baseDir.path}/$subPath');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error deleting $subPath: $e');
    }
  }

  Future<void> clearCacheDirectory() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list()) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  void showLogoutConfirmation() {
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
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: Colors.white,
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
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
                            await performBackgroundCleanup().timeout(
                              const Duration(seconds: 8),
                              onTimeout: () {},
                            );
                          } catch (e, stackTrace) {
                            debugPrint('LOGOUT cleanup failed: $e');
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
                            borderRadius: BorderRadius.circular(14),
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
            );
          },
        );
      },
    );
  }

  void showLanguageSelectionDialog() {
    LanguageSwitcher.showBottomSheet(context);
  }

  void onMenuSelected(String value) {
    switch (value) {
      case 'language':
        showLanguageSelectionDialog();
        break;
      case 'sync':
        performManualSync();
        break;
      case 'feedback':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FeedbackScreen()),
        );
        break;
      case 'about':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        );
        break;
      case 'logout':
        showLogoutConfirmation();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguageCode = Provider.of<LanguageService>(
      context,
    ).currentLocale.languageCode;

    final bool showDashboardSkeleton =
        isLoadingProfile || isRefreshingDashboard;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          onRefresh: refreshDashboard,
          color: AppColors.primaryGreen,
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    DashboardHeroHeader(onMenuSelected: onMenuSelected),
                    const SizedBox(height: 12),
                    WeatherCard(key: weatherCardKey, useDeviceLocation: true),
                    const SizedBox(height: 10),
                    showDashboardSkeleton
                        ? buildUpcomingNotificationSkeleton()
                        : UpcomingNotificationCard(
                            key: ValueKey(
                              'upcomingnotifications$notificationRefreshKey',
                            ),
                            backgroundColor: const Color(0xFF124D22),
                            daysAhead: 30,
                          ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: showDashboardSkeleton
                          ? buildProfileSkeleton()
                          : ProfileCard(
                              key: ValueKey('profilecard$profileRefreshKey'),
                              name: userData?['name'] ?? 'Guest User',
                              email: userData?['email'],
                              category: userData?['category'],
                              emailVerified:
                                  userData?['emailverified'] ?? false,
                              profileImagePath: userData?['profileimagepath'],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfileScreen(),
                                  ),
                                ).then((_) => refreshDashboard());
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: showDashboardSkeleton
                          ? buildFeaturesSkeleton()
                          : buildModernFeatureBoard(currentLanguageCode),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildModernFeatureBoard(String currentLanguageCode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: FeatureGrid(
        key: ValueKey(
          '$currentLanguageCode${userData?['category'] ?? 'none'}$featuresRefreshKey',
        ),
        features: buildFeatures(),
        childAspectRatio: 1.02,
        spacing: 10,
      ),
    );
  }

  Widget buildWeatherSkeleton() {
    return Container(
      key: const ValueKey('weatherskeleton'),
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD6DFC7)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE7B8),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                skeletonLine(width: 120, height: 14),
                const SizedBox(height: 8),
                skeletonLine(width: 100, height: 26),
                const SizedBox(height: 8),
                skeletonLine(width: 130, height: 12),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F5E4),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildUpcomingNotificationSkeleton() {
    return Container(
      key: const ValueKey('notificationskeleton'),
      margin: const EdgeInsets.symmetric(horizontal: 14),
      height: 118,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3920), Color(0xFF005D2F)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.14),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFB7D36E), width: 4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  skeletonLine(width: 100, height: 15, dark: true),
                  const SizedBox(height: 8),
                  skeletonLine(width: 80, height: 12, dark: true),
                  const SizedBox(height: 8),
                  skeletonLine(width: 150, height: 10, dark: true),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProfileSkeleton() {
    return Container(
      key: const ValueKey('profileskeleton'),
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD6DFC7)),
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE7ECD8),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                skeletonLine(width: 120, height: 15),
                const SizedBox(height: 8),
                skeletonLine(width: 100, height: 12),
                const SizedBox(height: 8),
                skeletonLine(width: 150, height: 14),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F5E4),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFeaturesSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        key: const ValueKey('featuresskeleton'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBF5),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD5DEC5)),
        ),
        child: GridView.builder(
          itemCount: 9,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.02,
          ),
          itemBuilder: (_, __) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDCE3CF)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget skeletonLine({
    required double width,
    required double height,
    bool dark = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withOpacity(0.22)
            : AppColors.primaryGreen.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class DashboardHeroHeader extends StatelessWidget {
  final ValueChanged<String> onMenuSelected;

  const DashboardHeroHeader({super.key, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      height: 205 + topInset,
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        image: DecorationImage(
          image: AssetImage('assets/images/dashboard_bg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(26),
            bottomRight: Radius.circular(26),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A3B1F).withOpacity(0.60),
              const Color(0xFF1C5A2A).withOpacity(0.30),
              const Color(0xFFB6A64A).withOpacity(0.10),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, topInset + 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Spacer(),
                  _DashboardSettingsButton(onSelected: onMenuSelected),
                ],
              ),
              const Spacer(),
              Icon(
                Icons.eco_outlined,
                color: Colors.lightGreen.shade300,
                size: 36,
              ),
              const SizedBox(height: 6),
              const SmartReTranslator(
                text: 'Welcome',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(
                    child: SmartReTranslator(
                      text: 'Better Farming, Better Harvest.',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFFFF27E),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.spa_rounded,
                    color: Colors.lightGreen.shade300,
                    size: 15,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _DashboardSettingsButton extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _DashboardSettingsButton({required this.onSelected});

  static const double _menuWidth = 198;
  static const double _gapBelowButton = 6;

  Future<void> _openMenu(BuildContext buttonContext) async {
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final button = buttonContext.findRenderObject() as RenderBox;

    final buttonBottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    final screenSize = overlay.size;

    double left = buttonBottomRight.dx - _menuWidth;
    if (left < 12) left = 12;
    if (left + _menuWidth > screenSize.width - 12) {
      left = screenSize.width - _menuWidth - 12;
    }

    final top = buttonBottomRight.dy + _gapBelowButton;

    final selected = await showGeneralDialog<String>(
      context: buttonContext,
      barrierLabel: 'Dashboard menu',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.08),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: _menuWidth,
                child: _DashboardDropdownMenu(
                  onSelected: (value) => Navigator.of(context).pop(value),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(curved),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (selected != null) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return Semantics(
          button: true,
          label: 'Open dashboard menu',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openMenu(buttonContext),
              customBorder: const CircleBorder(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade900.withOpacity(0.88),
                      Colors.green.shade700.withOpacity(0.76),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.16),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardDropdownMenu extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _DashboardDropdownMenu({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(0),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFEF9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD7E3C8), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.green.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DashboardMenuAction(
              value: 'language',
              onSelected: onSelected,
              child: const _DashboardMenuTile(
                icon: Icons.language_outlined,
                iconColor: Color(0xFF7A4BC2),
                iconBg: Color(0xFFEDE4FB),
                text: 'Language',
              ),
            ),
            _DashboardMenuAction(
              value: 'sync',
              onSelected: onSelected,
              child: const _DashboardMenuTile(
                icon: Icons.sync_rounded,
                iconColor: Color(0xFF2D8A57),
                iconBg: Color(0xFFE2F4E8),
                text: 'Sync',
              ),
            ),
            _DashboardMenuAction(
              value: 'feedback',
              onSelected: onSelected,
              child: const _DashboardMenuTile(
                icon: Icons.feedback_rounded,
                iconColor: Color(0xFF2D8A57),
                iconBg: Color(0xFFE2F4E8),
                text: 'Feedback',
              ),
            ),
            _DashboardMenuAction(
              value: 'about',
              onSelected: onSelected,
              child: const _DashboardMenuTile(
                icon: Icons.info_outline_rounded,
                iconColor: Color(0xFFE08A1E),
                iconBg: Color(0xFFFFF0D9),
                text: 'About Us',
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFE2EAD7)),
            ),
            _DashboardMenuAction(
              value: 'logout',
              onSelected: onSelected,
              child: const _DashboardMenuTile(
                icon: Icons.logout_rounded,
                iconColor: Color(0xFFC44545),
                iconBg: Color(0xFFFBE4E4),
                text: 'Logout',
                isDanger: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardMenuAction extends StatelessWidget {
  final String value;
  final Widget child;
  final ValueChanged<String> onSelected;

  const _DashboardMenuAction({
    required this.value,
    required this.child,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onSelected(value),
        child: child,
      ),
    );
  }
}

class _DashboardMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String text;
  final bool isDanger;

  const _DashboardMenuTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.text,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF4),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFDCE7D0), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SmartReTranslator(
              text: text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDanger
                    ? const Color(0xFFB53D3D)
                    : const Color(0xFF244628),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: isDanger ? const Color(0xFFCC6B6B) : const Color(0xFF8AA07E),
          ),
        ],
      ),
    );
  }
}
