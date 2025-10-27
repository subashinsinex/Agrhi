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

  // Configure FlutterSecureStorage with proper options
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

  /// Read from storage with retry mechanism (same as AuthService)
  Future<String?> _readWithRetry(String key, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final value = await _storage.read(key: key);
        if (value != null && value.isNotEmpty) {
          return value;
        }
        // Wait before retry
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

      // Use retry logic to read profile
      final profileJson = await _readWithRetry('user_profile');

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
          if (mounted) {
            setState(() => _isLoadingProfile = false);
          }
        }
      } else {
        print('⚠️ User profile not found in storage');
        if (mounted) {
          setState(() => _isLoadingProfile = false);
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
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
    };

    Map<String, String> newTranslated = {};
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
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: AppColors.textWhite,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          translatedTexts['notificationsComingSoon'] ??
                              'Notifications feature coming soon!',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.successColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            tooltip: translatedTexts['notifications'] ?? 'Notifications',
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

  /// Build a skeleton loader that looks like the profile card
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
