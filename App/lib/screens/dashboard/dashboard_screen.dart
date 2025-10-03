import 'package:flutter/material.dart';
import '../shared/sidebar.dart';
import '../shared/placeholder_screen.dart';
import '../shared/widgets/custom_app_bar.dart';
import '../../utils/colors.dart';
import '../../flutter_gen/gen_l10n/app_localizations.dart';
import 'components/weather_card.dart';
import 'components/profile_card.dart';
import 'components/feature_grid.dart';

import '../features/disease_detection_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? userData;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    final l10n = AppLocalizations.of(context);
    _navigateToFeature(l10n.myDetails, Icons.person);
  }

  void _openSidebar() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // ✅ Direct approach - create features list with direct localization access
    final features = [
      FeatureItem(
        title: l10n.cropManagement, // ✅ Direct access to translation
        icon: Icons.agriculture,
        onTap: () => _navigateToFeature(l10n.cropManagement, Icons.agriculture),
      ),
      FeatureItem(
        title: l10n.diseaseDetection,
        icon: Icons.biotech,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DetectDiseaseScreen(),
          ),
        ),
      ),
      FeatureItem(
        title: l10n.soilInformation, // ✅ Direct access to translation
        icon: Icons.grass,
        onTap: () => _navigateToFeature(l10n.soilInformation, Icons.grass),
      ),
      FeatureItem(
        title: l10n.marketPrices, // ✅ Direct access to translation
        icon: Icons.attach_money,
        onTap: () => _navigateToFeature(l10n.marketPrices, Icons.attach_money),
      ),
      FeatureItem(
        title: l10n.expertAdvice, // ✅ Direct access to translation
        icon: Icons.person,
        onTap: () => _navigateToFeature(l10n.expertAdvice, Icons.person),
      ),
      FeatureItem(
        title: l10n.detectionHistory, // ✅ Direct access to translation
        icon: Icons.history,
        onTap: () => _navigateToFeature(l10n.detectionHistory, Icons.history),
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
                  content: const Row(
                    children: [
                      Icon(Icons.info, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Notifications feature coming soon!'),
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
            tooltip: 'Notifications',
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
              // Weather Card Component
              WeatherCard(
                location: "Chennai",
              ),

              const SizedBox(height: 10),

              // My Details Section Header
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    l10n.myDetails,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Profile Card Component
              ProfileCard(
                name: userData != null
                    ? (userData!['name'] as String? ?? 'John Doe')
                    : 'John Doe',
                email: userData != null
                    ? (userData!['email'] as String? ?? 'johndoe@gmail.com')
                    : null,
                plotArea: "Plot area : 12345 acres",
                totalPlots: 90,
                totalCrops: 36,
                onTap: _onProfileTap,
              ),

              const SizedBox(height: 20),

              // Features Section Header
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    l10n.features, // ✅ Direct translation access
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Simplified Feature Grid - No translation logic needed here
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

// ✅ Simplified Feature Grid - No translation switch statements needed!
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

          // ✅ No translation logic needed - title is already translated!
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
                    feature.title, // ✅ Already translated string
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
