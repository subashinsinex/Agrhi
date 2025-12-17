// lib/src/screens/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;
import 'dart:convert';
import '../../utils/colors.dart';
import '../../utils/routes.dart';
import '../../src/services/auth_service.dart';
import '../../src/services/sync_service.dart';
import '../../src/services/crop_care_sync_service.dart';
import '../../src/services/app_config_service.dart';
import '../../src/database/database_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static MaterialPageRoute route() =>
      MaterialPageRoute(builder: (context) => const SplashScreen());

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  String _statusMessage = 'Initializing...';
  bool _showOfflineBadge = false;
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

  // ✅ Check if there's unsynced data using your DatabaseHelper
  Future<bool> _hasUnsyncedData() async {
    try {
      final db = DatabaseHelper.instance;

      // Check pending farms
      final pendingFarms = await db.getPendingFarms();

      // Check pending crops
      final pendingCrops = await db.getPendingCrops();

      // Check pending disease analyses
      final pendingAnalyses = await db.getPendingAnalyses();

      // Check pending deletions
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

  // ✅ Drop database after successful sync
  Future<void> _dropDatabase() async {
    try {
      // Close existing database
      await DatabaseHelper.instance.close();

      // Delete the database file
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'agrhi_offline.db');
      await deleteDatabase(path);

      debugPrint('✅ Database dropped successfully');
    } catch (e) {
      debugPrint('❌ Error dropping database: $e');
      rethrow;
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

    // ✅ STEP 1: Check if update is needed
    setState(() => _statusMessage = 'Checking for updates...');

    final serverConfig = await AppConfigService.checkAppConfig();

    if (serverConfig != null && mounted) {
      final needsUpdate = serverConfig['needs_update'] == true;

      if (needsUpdate) {
        // ✅ Update is required - start update flow
        await _handleUpdateFlow(serverConfig);
        return;
      }
    }

    // ✅ STEP 2: No update needed, proceed with auth
    if (!mounted) return;
    await _proceedWithAuth();
  }

  // ✅ Handle complete update flow with sync
  Future<void> _handleUpdateFlow(Map<String, dynamic> config) async {
    try {
      setState(
        () => _statusMessage = 'Update required. Checking offline data...',
      );
      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ Check if there's unsynced data
      final hasUnsynced = await _hasUnsyncedData();

      if (!mounted) return;

      if (hasUnsynced) {
        // ✅ Has unsynced data - must sync first
        final syncSuccess = await _showSyncBeforeUpdateDialog(config);

        if (!syncSuccess) {
          // Sync failed or user skipped - show warning
          await _showForceUpdateWarningDialog(config);
        } else {
          // Sync successful - drop database and update
          await _dropDatabaseAndUpdate(config);
        }
      } else {
        // ✅ No unsynced data - safe to update directly
        await _showDirectUpdateDialog(config);
      }
    } catch (e) {
      debugPrint('❌ Error in update flow: $e');
      if (mounted) {
        await _showDirectUpdateDialog(config);
      }
    }
  }

  // ✅ Show dialog: Sync required before update
  Future<bool> _showSyncBeforeUpdateDialog(Map<String, dynamic> config) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.sync, color: AppColors.primaryGreen, size: 28),
              const SizedBox(width: 12),
              const Expanded(child: Text('Sync Required')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have offline data that needs to be synced before updating.',
                style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                'This ensures your data is safely stored on the server.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Skip',
                style: TextStyle(color: AppColors.errorColor),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.primaryWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              onPressed: () async {
                Navigator.pop(context, true);
              },
              child: const Text('Sync Now'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      // User chose to sync - perform sync
      return await _performUpdateSync();
    }

    return false;
  }

  // ✅ Perform sync before update
  Future<bool> _performUpdateSync() async {
    try {
      setState(() => _statusMessage = 'Syncing offline data...');

      final accessToken = await _getValidAccessTokenForSync();

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('⚠️ No valid access token for sync');
        if (mounted) {
          _showErrorDialog(
            'Sync Failed',
            'Unable to authenticate. Please login again.',
          );
        }
        return false;
      }

      final results =
          await Future.wait([
            SyncService.instance.performFullSync(accessToken),
            CropCareSyncService.instance.performFullSync(accessToken),
          ]).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('⚠️ Sync timeout');
              return [
                {'success': false, 'error': 'timeout'},
                {'success': false, 'error': 'timeout'},
              ];
            },
          );

      final diseaseSync = results[0];
      final cropCareSync = results[1];

      final syncSuccess =
          diseaseSync['success'] == true && cropCareSync['success'] == true;

      if (!syncSuccess) {
        debugPrint('❌ Sync failed');
        if (mounted) {
          _showErrorDialog(
            'Sync Failed',
            'Unable to sync all data. Please check your connection and try again.',
          );
        }
        return false;
      }

      debugPrint('✅ Sync completed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Sync error: $e');
      if (mounted) {
        _showErrorDialog('Sync Error', 'An error occurred during sync: $e');
      }
      return false;
    }
  }

  // ✅ Drop database and proceed to update
  Future<void> _dropDatabaseAndUpdate(Map<String, dynamic> config) async {
    try {
      setState(() => _statusMessage = 'Preparing for update...');

      await _dropDatabase();

      debugPrint('✅ Database dropped successfully');

      if (mounted) {
        await _showDirectUpdateDialog(config);
      }
    } catch (e) {
      debugPrint('❌ Error dropping database: $e');
      if (mounted) {
        await _showDirectUpdateDialog(config);
      }
    }
  }

  // ✅ Show warning: Force update will lose data
  Future<void> _showForceUpdateWarningDialog(
    Map<String, dynamic> config,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warningColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('Warning'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Updating without syncing will permanently delete all offline data.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This cannot be undone. We strongly recommend syncing first.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // Try sync again
                final syncSuccess = await _performUpdateSync();
                if (syncSuccess) {
                  await _dropDatabaseAndUpdate(config);
                } else {
                  await _showForceUpdateWarningDialog(config);
                }
              },
              child: Text(
                'Try Sync Again',
                style: TextStyle(color: AppColors.primaryGreen),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorColor,
                foregroundColor: AppColors.primaryWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _dropDatabaseAndUpdate(config);
              },
              child: const Text('Update Anyway'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Show direct update dialog (no sync needed)
  Future<void> _showDirectUpdateDialog(Map<String, dynamic> config) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.system_update,
                color: AppColors.primaryGreen,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('Update Required'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config['update_message'] ?? 'A new version is available.',
                style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                'Please update to continue using Agrhi.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.primaryWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              onPressed: () async {
                final storeUrl = config['store_url'] ?? '';
                if (storeUrl.isNotEmpty) {
                  final uri = Uri.parse(storeUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              child: const Text('Update Now', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Show error dialog
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ✅ Proceed with normal auth flow
  Future<void> _proceedWithAuth() async {
    setState(() => _statusMessage = 'Checking authentication...');
    await Future.delayed(const Duration(milliseconds: 500));

    final authStatus = await _authService.checkAuthStatus();

    if (!mounted) return;

    switch (authStatus) {
      case AuthStatus.authenticated:
        setState(() => _statusMessage = 'Welcome back!');
        await Future.delayed(const Duration(milliseconds: 500));
        await _performBackgroundSync();
        if (mounted) Routes.navigateToDashboard(context);
        break;

      case AuthStatus.authenticatedOffline:
        final daysRemaining = await _authService.getRefreshTokenDaysRemaining();
        setState(() {
          _statusMessage =
              'Offline mode (${daysRemaining ?? 0} days remaining)';
          _showOfflineBadge = true;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Routes.navigateToDashboard(context);
        break;

      case AuthStatus.unauthenticated:
        setState(() => _statusMessage = 'Redirecting to login...');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Routes.navigateToLogin(context);
        break;
    }
  }

  Future<void> _performBackgroundSync() async {
    try {
      if (!mounted) return;

      setState(() => _statusMessage = 'Syncing data...');

      final accessToken = await _getValidAccessTokenForSync();

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('⚠️ No valid access token available for sync');
        if (mounted) {
          setState(() => _statusMessage = 'Welcome back!');
        }
        return;
      }

      final results =
          await Future.wait([
            SyncService.instance.performFullSync(accessToken),
            CropCareSyncService.instance.performFullSync(accessToken),
          ]).timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              debugPrint('⚠️ Sync timeout - continuing anyway');
              return [
                {'success': false, 'error': 'timeout'},
                {'success': false, 'error': 'timeout'},
              ];
            },
          );

      final diseaseSync = results[0];
      final cropCareSync = results[1];

      if (diseaseSync['success'] == true) {
        debugPrint('✅ Disease analysis sync completed');
      }

      if (cropCareSync['success'] == true) {
        debugPrint('✅ Crop care sync completed');
      }

      if (mounted) {
        setState(() => _statusMessage = 'Sync complete!');
      }

      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('❌ Background sync error: $e');
      if (mounted) {
        setState(() => _statusMessage = 'Welcome back!');
      }
    }
  }

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
          padding: const EdgeInsets.all(20),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Agrhi',
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
