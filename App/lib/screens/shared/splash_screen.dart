// lib/src/screens/splash/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/colors.dart';
import '../../utils/routes.dart';
import '../../src/services/app_config_service.dart';
import '../../src/database/database_helper.dart';
import '../shared/update_screen.dart';
import '../../src/services/sync_service.dart';
import '../../src/services/connectivity_manager.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  String _statusMessage = 'Initializing...';
  final bool _showOfflineBadge = false;
  bool _configChecked = false;

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
    _setupAnimations();
    _checkAuthAndNavigate();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  Future<bool> _hasUnsyncedData() async {
    try {
      final db = DatabaseHelper.instance;

      final pendingFarms = await db.getPendingFarms();
      final pendingCrops = await db.getPendingCrops();
      final pendingAnalyses = await db.getPendingAnalyses();
      final pendingFarmDeletions = await db.getPendingFarmDeletions();
      final pendingCropDeletions = await db.getPendingCropDeletions();

      final hasUnsynced =
          pendingFarms.isNotEmpty ||
          pendingCrops.isNotEmpty ||
          pendingAnalyses.isNotEmpty ||
          pendingFarmDeletions.isNotEmpty ||
          pendingCropDeletions.isNotEmpty;

      debugPrint('📊 Unsynced data check:');
      debugPrint('  Farms: ${pendingFarms.length}');
      debugPrint('  Crops: ${pendingCrops.length}');
      debugPrint('  Analyses: ${pendingAnalyses.length}');
      debugPrint('  Farm deletions: ${pendingFarmDeletions.length}');
      debugPrint('  Crop deletions: ${pendingCropDeletions.length}');

      return hasUnsynced;
    } catch (e) {
      debugPrint('❌ Error checking unsynced data: $e');
      return false;
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (_configChecked) {
      debugPrint('⚠️ Config already checked, skipping...');
      return;
    }
    _configChecked = true;

    setState(() => _statusMessage = 'Checking for updates...');

    final serverConfig = await AppConfigService.checkAppConfig();

    if (serverConfig != null && mounted) {
      final needsUpdate = serverConfig['needs_update'] == true;

      if (needsUpdate) {
        await _handleUpdateFlow(serverConfig);
        return;
      }
    }

    if (!mounted) return;
    await _proceedWithAuth();
  }

  Future<void> _handleUpdateFlow(Map<String, dynamic> config) async {
    try {
      setState(
        () => _statusMessage = 'Update required. Checking offline data...',
      );
      await Future.delayed(const Duration(milliseconds: 500));

      final hasUnsynced = await _hasUnsyncedData();

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              UpdateScreen(config: config, hasUnsyncedData: hasUnsynced),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error in update flow: $e');
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                UpdateScreen(config: config, hasUnsyncedData: false),
          ),
        );
      }
    }
  }

Future<void> _proceedWithAuth() async {
  if (!mounted) return;
  
  setState(() => _statusMessage = 'Loading...');
  await Future.delayed(const Duration(milliseconds: 500));

  // ✅ Simple token existence check - no validation, no refresh
  final hasTokens = await _hasStoredTokens();

  if (!mounted) return;

  if (hasTokens) {
    setState(() => _statusMessage = 'Welcome back!');
    await Future.delayed(const Duration(milliseconds: 300));

    // 🔁 Start full sync in background (non-blocking)
    final accessToken = await _storage.read(key: 'access_token');
    if (accessToken != null && accessToken.isNotEmpty) {
      // Don't await - let it run in background
      SyncService.instance.performFullSync(accessToken).then((fullSyncResult) {
        debugPrint('🔁 Full sync from splash: $fullSyncResult');
        
        if (fullSyncResult['success'] == true && mounted) {
          try {
            final connectivityManager = context.read<ConnectivityManager>();
            connectivityManager.updateLastSyncTime(DateTime.now());
          } catch (e) {
            debugPrint('⚠️ Could not update sync time: $e');
          }
        }
      }).catchError((e) {
        debugPrint('❌ Full sync from splash failed: $e');
      });
    } else {
      debugPrint('⚠️ No access token found, skipping full sync');
    }

    // Navigate immediately without waiting for sync
    if (mounted) Routes.navigateToDashboard(context);
  } else {
    setState(() => _statusMessage = 'Redirecting to login...');
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) Routes.navigateToLogin(context);
  }
}


  // ✅ NEW: Simple token existence check - no validation
  Future<bool> _hasStoredTokens() async {
    try {
      final accessToken = await _storage.read(key: 'access_token');
      final refreshToken = await _storage.read(key: 'refresh_token');

      final hasTokens =
          accessToken != null &&
          accessToken.isNotEmpty &&
          refreshToken != null &&
          refreshToken.isNotEmpty;

      debugPrint('🔐 Token check: ${hasTokens ? "Found" : "Not found"}');

      return hasTokens;
    } catch (e) {
      debugPrint('❌ Error checking tokens: $e');
      return false;
    }
  }

  // ❌ REMOVED: _getValidAccessTokenForSync()
  // ❌ REMOVED: _performBackgroundSync()
  // ❌ REMOVED: _readWithRetry()
  // ❌ REMOVED: _decodeJwtPayload()
  // ❌ REMOVED: _getJwtExpiryUtc()

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  _buildLogo(isSmallScreen),
                  SizedBox(height: isSmallScreen ? 32 : 40),
                  _buildTitle(),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  _buildSubtitle(),
                  const Spacer(flex: 4),
                  _buildStatusSection(),
                  SizedBox(height: isSmallScreen ? 50 : 70),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isSmallScreen) {
    final logoSize = isSmallScreen ? 140.0 : 170.0;

    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        color: AppColors.primaryWhite,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'AGRHI',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w900,
        color: AppColors.primaryGreen,
        letterSpacing: 4,
        height: 1.0,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Smart Farm App',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _showOfflineBadge
              ? _buildOfflineBadge()
              : const SizedBox.shrink(),
        ),
        SizedBox(height: _showOfflineBadge ? 24 : 0),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    ),
                child: child,
              ),
            );
          },
          child: Padding(
            key: ValueKey(_statusMessage),
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryGreen,
                  ),
                  strokeCap: StrokeCap.round,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineBadge() {
    return Container(
      key: const ValueKey('offline_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primaryWhite,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.warningColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.warningColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.wifi_off_rounded, size: 20, color: AppColors.warningColor),
          const SizedBox(width: 10),
          Text(
            'Offline Mode',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.warningColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
