import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../shared/sidebar.dart';
import '../shared/placeholder_screen.dart';
import '../shared/widgets/custom_app_bar.dart';
import '../../utils/colors.dart';
import '../../src/services/language_service.dart';
import '../components/weather_card.dart';
import '../components/profile_card.dart';
import '../components/feature_grid.dart';
import '../features/disease_detection_screen.dart';
import '../features/subsidy_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../src/database/database_helper.dart';
import '../../src/services/auth_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? userData;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, String> translatedTexts = {};
  String _currentLanguage = '';
  bool _isLoadingProfile = true;
  final AuthService _authService = AuthService();

  // Keep the State field only
  bool _isSyncing = false;

  // Secure storage with options
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
      _loadTranslations();
      _loadUserData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageService = Provider.of<LanguageService>(context);
    if (_currentLanguage != languageService.currentLocale.languageCode) {
      _currentLanguage = languageService.currentLocale.languageCode;
      _loadTranslations();
    }
  }

  /// Generic storage read with retry
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
        print('❌ Storage read attempt ${i + 1} failed for $key: $e');
        if (i == maxRetries - 1) rethrow;
      }
    }
    return null;
  }

  /// Load user profile data from secure storage with retry
  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoadingProfile = true);

    try {
      print('📋 Loading user profile from storage...');
      final profileJson = await _readWithRetry('user_profile');
      final userId = await _readWithRetry('user_id');
      print('📋 User ID: ${userId ?? "NULL"}');
      print(
        '📋 Profile JSON: ${profileJson != null ? "Found (${profileJson.length} chars)" : "NULL"}',
      );

      if (profileJson != null) {
        try {
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
            print('✅ User profile loaded successfully: ${userData?['name']}');
          }
        } catch (e) {
          print('❌ Error parsing user profile JSON: $e');
          if (mounted) setState(() => _isLoadingProfile = false);
        }
      } else {
        print('⚠️ User profile not found in storage');
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadTranslations() async {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    final keys = {
      'profile': 'Profile',
      'guestUser': 'Guest User',
      'features': 'Features',
      'cropManagement': 'Crop Management',
      'diseaseDetection': 'Disease Detection',
      'subsidy': 'Subsidy',
      'cropHistory': 'Crop History',
      'expertAdvice': 'Expert Advice',
      'detectionHistory': 'Detection History',
      'notifications': 'Notifications',
      'notificationsComingSoon': 'Notifications feature coming soon!',
      'sync': 'Sync',
      'syncing': 'Sync in progress...',
      'syncComplete': 'Sync complete',
      'syncPartial': 'Sync finished with some issues',
      'syncFailed': 'Sync failed. Please try again.',
      'sessionExpired': 'Session expired. Please log in again.',
      'noToken': 'Authentication required. Please log in.',
    };

    final newTranslated = <String, String>{};
    for (var entry in keys.entries) {
      newTranslated[entry.key] = await languageService.translate(entry.value);
    }

    if (mounted) {
      setState(() {
        translatedTexts = newTranslated;
      });
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

  // ==== JWT helpers ====

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      String payload = parts[1];

      // Fix base64url padding
      int mod4 = payload.length % 4;
      if (mod4 > 0) {
        payload += '=' * (4 - mod4);
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded);
      if (map is Map<String, dynamic>) return map;
      if (map is Map) return Map<String, dynamic>.from(map);
      return null;
    } catch (_) {
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

  // Optimized: get valid access token with JWT expiry check and refresh (fallback to stored expiry)
  Future<String?> _getValidAccessTokenForSync() async {
    // Read token
    String? accessToken =
        await _readWithRetry('access_token') ??
        await _storage.read(key: 'access_token');

    // Read supported stored expiry fields (fallback path)
    String? expiryIso =
        await _readWithRetry('access_token_expires_at') ??
        await _storage.read(key: 'access_token_expires_at');

    String? expiryEpochMsStr =
        await _readWithRetry('access_token_expiry') ??
        await _storage.read(key: 'access_token_expiry');

    bool isExpired = false;
    final now = DateTime.now().toUtc();
    const skew = Duration(seconds: 60);

    // Prefer JWT exp if token available
    if (accessToken != null && accessToken.isNotEmpty) {
      final jwtExp = _getJwtExpiryUtc(accessToken);
      if (jwtExp != null) {
        isExpired = now.add(skew).isAfter(jwtExp);
      } else {
        // Fallback to stored metadata if JWT has no exp
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
            // No metadata — assume still valid if token exists
            isExpired = false;
          }
        } catch (_) {
          // If parsing fails, attempt refresh
          isExpired = true;
        }
      }
    } else {
      isExpired = true; // No token found
    }

    if (!isExpired && accessToken != null && accessToken.isNotEmpty) {
      return accessToken;
    }

    // Refresh token using your auth service; it should update secure storage
    try {
      print('🔄 Attempting to refresh access token (JWT check path)...');
      await _authService.refreshAccessToken();
      print('✅ Access token refreshed successfully');

      // Re-read token and re-check JWT expiry
      accessToken =
          await _readWithRetry('access_token') ??
          await _storage.read(key: 'access_token');

      if (accessToken == null || accessToken.isEmpty) {
        print('❌ Refresh succeeded but no access_token found in storage');
        return null;
      }

      final jwtExp = _getJwtExpiryUtc(accessToken);
      if (jwtExp != null) {
        final stillExpired = now.add(skew).isAfter(jwtExp);
        return stillExpired ? null : accessToken;
      }

      // If no exp in JWT, accept refreshed token
      return accessToken;
    } catch (e) {
      print('❌ Failed to refresh access token: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final features = [
      FeatureItem(
        title: translatedTexts['cropManagement'] ?? 'Crop Management',
        icon: Icons.agriculture,
        onTap: () => _navigateToFeature(
          translatedTexts['cropManagement'] ?? 'Crop Management',
          Icons.agriculture,
        ),
      ),
      FeatureItem(
        title: translatedTexts['diseaseDetection'] ?? 'Disease Detection',
        icon: Icons.biotech,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DetectDiseaseScreen()),
        ),
      ),
      FeatureItem(
        title: translatedTexts['subsidy'] ?? 'Subsidy',
        icon: Icons.monetization_on,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SubsidyScreen()),
        ),
      ),
      FeatureItem(
        title: translatedTexts['cropHistory'] ?? 'Crop History',
        icon: Icons.history_edu,
        onTap: () => _navigateToFeature(
          translatedTexts['cropHistory'] ?? 'Crop History',
          Icons.history_edu,
        ),
      ),
      FeatureItem(
        title: translatedTexts['expertAdvice'] ?? 'Expert Advice',
        icon: Icons.person,
        onTap: () => _navigateToFeature(
          translatedTexts['expertAdvice'] ?? 'Expert Advice',
          Icons.person,
        ),
      ),
      FeatureItem(
        title: translatedTexts['detectionHistory'] ?? 'Detection History',
        icon: Icons.history,
        onTap: () => _navigateToFeature(
          translatedTexts['detectionHistory'] ?? 'Detection History',
          Icons.history,
        ),
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: DashboardAppBar.withMenu(
  onMenuPressed: _openSidebar,
  additionalActions: [
    Padding(
      padding: const EdgeInsetsDirectional.only(end: 12), // was margin: end: 4
      child: IconButton(
        tooltip: translatedTexts['sync'] ?? 'Sync',
        onPressed: _isSyncing
            ? null
            : () async {
                setState(() => _isSyncing = true);

                final messenger = ScaffoldMessenger.of(context);

                // Ensure token is valid (JWT check + refresh if needed)
                final validToken = await _getValidAccessTokenForSync();
                if (validToken == null || validToken.isEmpty) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        translatedTexts['sessionExpired'] ??
                            'Session expired. Please log in again.',
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

                // Feedback: sync starting
                messenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            translatedTexts['syncing'] ??
                                'Sync in progress...',
                          ),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.infoColor,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );

                try {
                  // Reuse your existing smart sync
                  final syncResult = await DatabaseHelper.instance
                      .smartSyncCatalogs(validToken);

                  final bool ok = (syncResult['success'] as bool?) ?? false;
                  final int updated = (syncResult['updated'] as int?) ?? 0;
                  final int failedCount =
                      (syncResult['failed'] as List?)?.length ?? 0;

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? (translatedTexts['syncComplete'] ??
                                'Sync complete: $updated table(s) updated.')
                            : (translatedTexts['syncPartial'] ??
                                'Sync finished: $updated updated, $failedCount failed.'),
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor:
                          ok ? AppColors.successColor : AppColors.warningColor,
                      duration: const Duration(seconds: 3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );

                  if (ok) {
                    // ignore: avoid_print
                    print('✅ Synced $updated tables');
                  } else {
                    // ignore: avoid_print
                    print('⚠️ ${syncResult['message']}');
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        translatedTexts['syncFailed'] ??
                            'Sync failed. Please try again.',
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.errorColor,
                      duration: const Duration(seconds: 3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _isSyncing = false);
                }
              },
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
                WeatherCard(location: "Chennai"),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      translatedTexts['profile'] ?? 'Profile',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Show skeleton loader while loading, then profile card
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isLoadingProfile
                      ? _buildProfileSkeleton()
                      : ProfileCard(
                          key: const ValueKey('profile_card'),
                          name:
                              userData?['name'] ??
                              translatedTexts['guestUser'] ??
                              'Guest User',
                          email: userData?['email'],
                          phone: userData?['phone'],
                          category: userData?['category'],
                          address: userData?['address'],
                        ),
                ),

                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      translatedTexts['features'] ?? 'Features',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DirectFeatureGrid(
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

  /// Profile skeleton
  Widget _buildProfileSkeleton() {
    return Container(
      key: const ValueKey('profile_skeleton'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryWhite,
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
          // Avatar skeleton
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          // Text skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name skeleton
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                // Email skeleton
                Container(
                  width: 150,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                // Phone skeleton
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
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
                  child: Text(
                    feature.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
