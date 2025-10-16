import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? userData;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, String> translatedTexts = {};
  String _currentLanguage = ''; // Track current language

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTranslations();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Automatically reload when language changes
    final languageService = Provider.of<LanguageService>(context);
    if (_currentLanguage != languageService.currentLocale.languageCode) {
      _currentLanguage = languageService.currentLocale.languageCode;
      _loadTranslations();
    }
  }

  Future<void> _loadTranslations() async {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    final keys = {
      'myDetails': 'My Details',
      'johnDoe': 'John Doe',
      'plotArea': 'Plot area',
      'acres': 'acres',
      'features': 'Features',
      'cropManagement': 'Crop Management',
      'diseaseDetection': 'Disease Detection',
      'subsidy': 'Subsidy',
      'marketPrices': 'Market Prices',
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

  void _onProfileTap() {
    _navigateToFeature(
      translatedTexts['myDetails'] ?? 'My Details',
      Icons.person,
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
        title: translatedTexts['marketPrices'] ?? 'Market Prices',
        icon: Icons.attach_money,
        onTap: () => _navigateToFeature(
          translatedTexts['marketPrices'] ?? 'Market Prices',
          Icons.attach_money,
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
                    translatedTexts['myDetails'] ?? 'My Details',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ProfileCard(
                name: userData != null
                    ? (userData!['name'] as String? ??
                          (translatedTexts['johnDoe'] ?? 'John Doe'))
                    : (translatedTexts['johnDoe'] ?? 'John Doe'),
                email: userData != null
                    ? (userData!['email'] as String? ?? 'johndoe@gmail.com')
                    : null,
                plotArea:
                    "${translatedTexts['plotArea'] ?? 'Plot area'} : 12345 ${translatedTexts['acres'] ?? 'acres'}",
                totalPlots: 90,
                totalCrops: 36,
                onTap: _onProfileTap,
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
        physics: const ClampingScrollPhysics(),
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
