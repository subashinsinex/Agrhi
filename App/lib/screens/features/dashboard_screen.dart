import 'package:agrhi/screens/features/model_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import '../shared/sidebar.dart';
import '../shared/placeholder_screen.dart';
import '../shared/widgets/custom_app_bar.dart';
import '../../utils/colors.dart';
import '../../src/services/language_service.dart';
import '../../screens/shared/widgets/smart_retranslator.dart';
import '../components/weather_card.dart';
import '../components/profile_card.dart';
import '../components/feature_grid.dart';
import 'disease_detection_screen.dart';
import 'subsidy_screen.dart';
import 'disease_history_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../src/services/auth_service.dart';
import '../../src/services/sync_service.dart';

Future<void> printAllSecureStorage() async {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );
  final all = await storage.readAll();
  debugPrint('📦 Secure Storage: ${all.keys.join(", ")}');
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? userData;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoadingProfile = true;
  final AuthService _authService = AuthService();
  bool _isSyncing = false;

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
      _performSmartSync(force: false);
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

  void _navigateToFeature(String displayTitle, IconData icon) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PlaceholderScreen(title: displayTitle, icon: icon),
      ),
    );
  }

  void _openSidebar() {
    _scaffoldKey.currentState?.openDrawer();
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      String payload = parts[1];

      int mod4 = payload.length % 4;
      if (mod4 > 0) {
        payload += '=' * (4 - mod4);
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded);
      if (map is Map<String, dynamic>) return map;
      if (map is Map) return Map<String, dynamic>.from(map);
      return null;
    } catch (e) {
      debugPrint('JWT decode error: $e');
      return null;
    }
  }

  DateTime? _getJwtExpiryUtc(String token) {
    final payload = _decodeJwtPayload(token);
    if (payload == null) return null;

    final exp = payload['exp'];

    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    } else if (exp is String) {
      final n = int.tryParse(exp);
      if (n != null) {
        return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
      }
    }

    return null;
  }

  Future<String?> _getValidAccessTokenForSync() async {
    String? accessToken =
        await _readWithRetry('access_token') ??
        await _storage.read(key: 'access_token');

    String? expiryIso =
        await _readWithRetry('access_token_expires_at') ??
        await _storage.read(key: 'access_token_expires_at');

    String? expiryEpochMsStr =
        await _readWithRetry('access_token_expiry') ??
        await _storage.read(key: 'access_token_expiry');

    bool isExpired = false;
    final now = DateTime.now().toUtc();
    const skew = Duration(seconds: 60);

    if (accessToken != null && accessToken.isNotEmpty) {
      final jwtExp = _getJwtExpiryUtc(accessToken);
      if (jwtExp != null) {
        isExpired = now.add(skew).isAfter(jwtExp);
      } else {
        try {
          if (expiryIso != null && expiryIso.isNotEmpty) {
            final exp = DateTime.tryParse(expiryIso)?.toUtc();
            if (exp != null) isExpired = now.add(skew).isAfter(exp);
          } else if (expiryEpochMsStr != null && expiryEpochMsStr.isNotEmpty) {
            final ms = int.tryParse(expiryEpochMsStr);
            if (ms != null) {
              final exp = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
              isExpired = now.add(skew).isAfter(exp);
            }
          } else {
            isExpired = false;
          }
        } catch (_) {
          isExpired = true;
        }
      }
    } else {
      isExpired = true;
    }

    if (!isExpired && accessToken != null && accessToken.isNotEmpty) {
      return accessToken;
    }

    try {
      await _authService.refreshAccessToken();
      accessToken =
          await _readWithRetry('access_token') ??
          await _storage.read(key: 'access_token');

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('Token refresh succeeded but no access_token found');
        return null;
      }

      final jwtExp = _getJwtExpiryUtc(accessToken);
      if (jwtExp != null) {
        final stillExpired = now.add(skew).isAfter(jwtExp);
        return stillExpired ? null : accessToken;
      }

      return accessToken;
    } catch (e) {
      debugPrint('Failed to refresh access token: $e');
      return null;
    }
  }

  Future<void> _performSmartSync({bool force = false}) async {
    if (_isSyncing) return;

    if (!force) {
      try {
        final lastSyncStr = await _storage.read(key: 'last_sync_time');

        if (lastSyncStr != null && lastSyncStr.isNotEmpty) {
          final lastSync = DateTime.tryParse(lastSyncStr);
          if (lastSync != null) {
            final timeSinceSync = DateTime.now().difference(lastSync);

            if (timeSinceSync.inMinutes < 5) {
              debugPrint(
                'Skipping auto-sync - last synced ${timeSinceSync.inMinutes} min ago',
              );
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Error checking last sync time: $e');
      }
    }

    await _performSilentSync();

    try {
      await _storage.write(
        key: 'last_sync_time',
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error storing last sync time: $e');
    }
  }

  Future<void> _performSilentSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final validToken = await _getValidAccessTokenForSync();
      if (validToken == null || validToken.isEmpty) {
        if (mounted) setState(() => _isSyncing = false);
        return;
      }

      final syncResult = await SyncService.instance.performFullSync(validToken);

      final bool success = (syncResult['success'] as bool?) ?? false;

      if (success) {
        final catalogsResult = syncResult['catalogs'] as Map<String, dynamic>?;
        final twoWayResult =
            syncResult['two_way_sync'] as Map<String, dynamic>?;

        final catalogsUpdated = (catalogsResult?['updated'] as int?) ?? 0;
        final uploaded = (twoWayResult?['upload']?['upload'] as int?) ?? 0;
        final downloaded =
            (twoWayResult?['download']?['downloaded'] as int?) ?? 0;
        final imagesUploaded =
            (twoWayResult?['images']?['upload'] as int?) ?? 0;

        debugPrint(
          'Silent sync: catalogs=$catalogsUpdated, up=$uploaded, down=$downloaded, img=$imagesUploaded',
        );
      } else {
        debugPrint('Silent sync error: ${syncResult['error']}');
      }
    } catch (e) {
      debugPrint('Silent sync exception: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _performFullSync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    final messenger = ScaffoldMessenger.of(context);

    final validToken = await _getValidAccessTokenForSync();
    if (validToken == null || validToken.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: const SmartReTranslator(
            text: 'Session expired. Please log in again.',
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
      if (mounted) setState(() => _isSyncing = false);
      return;
    }

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

    try {
      final syncResult = await SyncService.instance.performFullSync(validToken);

      final bool success = (syncResult['success'] as bool?) ?? false;

      if (success) {
        final catalogsResult = syncResult['catalogs'] as Map<String, dynamic>?;
        final twoWayResult =
            syncResult['two_way_sync'] as Map<String, dynamic>?;

        final catalogsUpdated = (catalogsResult?['updated'] as int?) ?? 0;
        final uploaded = (twoWayResult?['upload']?['upload'] as int?) ?? 0;
        final downloaded =
            (twoWayResult?['download']?['downloaded'] as int?) ?? 0;
        final imagesUploaded =
            (twoWayResult?['images']?['upload'] as int?) ?? 0;

        // ✅ FIXED: Translatable sync success message
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
                const SizedBox(height: 4),
                SmartReTranslator(
                  text:
                      'Upload $uploaded, Downloaded $downloaded, Images $imagesUploaded, Catalogs updated $catalogsUpdated',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],            ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.successColor,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        await _storage.write(
          key: 'last_sync_time',
          value: DateTime.now().toIso8601String(),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: const SmartReTranslator(
              text: 'Sync finished with some issues',
              style: TextStyle(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.warningColor,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        debugPrint('Manual sync error: ${syncResult['error']}');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: const SmartReTranslator(
            text: 'Sync failed. Please try again.',
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
      debugPrint('Manual sync exception: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Features list created inside build method
    final features = [
      FeatureItem(
        title: 'Crop Care',
        icon: Icons.agriculture,
        onTap: () => _navigateToFeature('Crop Care', Icons.agriculture),
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SubsidyScreen()),
        ),
      ),
      FeatureItem(
        title: 'Crop History',
        icon: Icons.history_edu,
        onTap: () => _navigateToFeature('Crop History', Icons.history_edu),
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
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: DashboardAppBar.withMenu(
        onMenuPressed: _openSidebar,
        additionalActions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: IconButton(
              tooltip: 'Sync',
              onPressed: _isSyncing ? null : _performFullSync,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.sync_outlined, color: AppColors.textWhite),
            ),
          ),
        ],
      ),
      drawer: const AppSidebar(),
      drawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: 120,
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
                  useDeviceLocation: true),
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
                          phone: userData?['phone'],
                          category: userData?['category'],
                          address: userData?['address'],
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
                // ✅ FIXED: Grid with proper key for language changes
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.mediumGreenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.mediumGreenAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 150,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.mediumGreenAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.mediumGreenAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ FIXED: DirectFeatureGrid with proper translation support
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
                    // ✅ FIXED: Unique key for each feature title
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
