import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../utils/routes.dart';
import '../../../src/services/app_config_service.dart';
import '../../../src/database/database_helper.dart';
import '../shared/update_screen.dart';
import '../../../src/services/connectivity_manager.dart';
import '../../../src/services/reminders_manager.dart';
import '../../../src/services/notification_service.dart';
import '../../../utils/page_transitions.dart';

class SplashScreen extends StatefulWidget {
  final String? initialNotificationPayload;

  const SplashScreen({super.key, this.initialNotificationPayload});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  String _statusMessage = 'Initializing services...';
  String _progressName = 'Booting';

  double _progressValue = 0.08;

  final bool _showOfflineBadge = false;

  bool _configChecked = false;
  bool _hasNavigated = false;

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

    _setupAnimations();

    _updateProgress(
      step: 'Booting',
      message: 'Initializing services...',
      value: 0.08,
    );

    _checkAuthAndNavigate();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  double _scaleText(BuildContext context, double size) {
    final width = MediaQuery.of(context).size.width;

    final scaledBase = size * (width / 390).clamp(0.90, 1.12);

    final accessibilityScale = MediaQuery.of(context).textScaler.scale(1.0);

    return scaledBase * accessibilityScale.clamp(0.95, 1.08);
  }

  List<Shadow> get _softTextShadow => [
    Shadow(
      color: Colors.white.withOpacity(0.55),
      blurRadius: 10,
      offset: const Offset(0, 1),
    ),
    Shadow(
      color: const Color(0xFFB8CAA1).withOpacity(0.28),
      blurRadius: 18,
      offset: const Offset(0, 4),
    ),
  ];

  void _updateProgress({
    required String step,
    required String message,
    required double value,
  }) {
    if (!mounted || _hasNavigated) {
      return;
    }

    setState(() {
      _progressName = step;
      _statusMessage = message;
      _progressValue = value.clamp(0.0, 1.0);
    });
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

      debugPrint('Unsynced data check:');
      debugPrint('Farms: ${pendingFarms.length}');
      debugPrint('Crops: ${pendingCrops.length}');
      debugPrint('Analyses: ${pendingAnalyses.length}');
      debugPrint('Farm deletions: ${pendingFarmDeletions.length}');
      debugPrint('Crop deletions: ${pendingCropDeletions.length}');

      return hasUnsynced;
    } catch (e) {
      debugPrint('Error checking unsynced data: $e');
      return false;
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted || _hasNavigated) {
      return;
    }

    if (_configChecked) {
      debugPrint('Config already checked, skipping...');
      return;
    }

    _configChecked = true;

    _updateProgress(
      step: 'Updates',
      message: 'Checking for updates...',
      value: 0.20,
    );

    final serverConfig = await AppConfigService.checkAppConfig();

    if (!mounted || _hasNavigated) {
      return;
    }

    if (serverConfig != null && serverConfig['needs_update'] == true) {
      await _handleUpdateFlow(serverConfig);
      return;
    }

    if (!mounted || _hasNavigated) {
      return;
    }

    await _proceedWithAuth();
  }

  Future<void> _handleUpdateFlow(Map<String, dynamic> config) async {
    try {
      _updateProgress(
        step: 'Update Required',
        message: 'Checking offline data before update...',
        value: 0.32,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      final hasUnsynced = await _hasUnsyncedData();

      if (!mounted || _hasNavigated) {
        return;
      }

      _updateProgress(
        step: 'Redirecting',
        message: 'Opening update screen...',
        value: 1.0,
      );

      await Future.delayed(const Duration(milliseconds: 250));

      if (!mounted || _hasNavigated) {
        return;
      }

      _hasNavigated = true;

      await Navigator.of(context).pushReplacement(
        smoothPageRoute(
              UpdateScreen(config: config, hasUnsyncedData: hasUnsynced),
        ),
      );
    } catch (e) {
      debugPrint('Error in update flow: $e');

      if (mounted && !_hasNavigated) {
        _hasNavigated = true;

        await Navigator.of(context).pushReplacement(
          smoothPageRoute(
            UpdateScreen(config: config, hasUnsyncedData: false),
          ),
        );
      }
    }
  }

  Future<void> _proceedWithAuth() async {
    if (!mounted || _hasNavigated) {
      return;
    }

    _updateProgress(
      step: 'Authentication',
      message: 'Loading secure session...',
      value: 0.40,
    );

    await Future.delayed(const Duration(milliseconds: 500));

    final hasTokens = await _hasStoredTokens();

    if (!mounted || _hasNavigated) {
      return;
    }

    final payload = widget.initialNotificationPayload;

    if (payload != null && payload.isNotEmpty) {
      await _handleNotificationNavigation(payload, hasTokens);

      return;
    }

    if (hasTokens) {
      await _handleAuthenticatedBoot();
    } else {
      await _handleUnauthenticatedBoot();
    }
  }

  Future<void> _handleNotificationNavigation(
    String payload,
    bool hasTokens,
  ) async {
    debugPrint('Splash notification payload found: $payload');

    _updateProgress(
      step: 'Notification',
      message: 'Opening notification...',
      value: 0.55,
    );

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted || _hasNavigated) {
      return;
    }

    _hasNavigated = true;

    switch (payload) {
      case Routes.modelManager:
        if (hasTokens) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.dashboard, (route) => false);

          Navigator.of(context).pushNamed(Routes.modelManager);
        } else {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.login, (route) => false);
        }
        return;

      case Routes.dashboard:
        if (hasTokens) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.dashboard, (route) => false);
        } else {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.login, (route) => false);
        }
        return;

      case Routes.login:
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.login, (route) => false);
        return;

      case Routes.signup:
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(Routes.signup, (route) => false);
        return;

      default:
        if (hasTokens) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.dashboard, (route) => false);
        } else {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(Routes.login, (route) => false);
        }
        return;
    }
  }

  Future<void> _handleAuthenticatedBoot() async {
    _updateProgress(step: 'Welcome', message: 'Welcome back!', value: 0.52);

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted || _hasNavigated) {
      return;
    }

    _updateProgress(step: 'Sync', message: 'Syncing your data...', value: 0.68);

    try {
      final syncResult = await ConnectivityManager.instance.performManualSync(
        isBootSync: true,
      );

      debugPrint('✅ Boot sync result: $syncResult');

      if (!mounted || _hasNavigated) {
        return;
      }

      _updateProgress(
        step: 'Finishing',
        message: 'Finalizing setup...',
        value: 0.88,
      );

      try {
        await NotificationService.ensureGeneralEngagementNotificationsScheduled();

        debugPrint('✅ General engagement notifications checked');
      } catch (e) {
        debugPrint('Error checking engagement notifications: $e');
      }
    } catch (e) {
      debugPrint('Boot sync failed: $e');

      if (!mounted || _hasNavigated) {
        return;
      }

      _updateProgress(
        step: 'Offline Mode',
        message: 'Continuing offline...',
        value: 0.82,
      );

      try {
        await RemindersManager.instance.rescheduleAllCropReminders();

        await NotificationService.ensureGeneralEngagementNotificationsScheduled();

        debugPrint('✅ Offline reminders and engagement notifications restored');
      } catch (restoreError) {
        debugPrint(
          'Error restoring reminders after sync failure: $restoreError',
        );
      }
    }

    if (!mounted || _hasNavigated) {
      return;
    }

    _updateProgress(step: 'Ready', message: 'Opening dashboard...', value: 1.0);

    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted || _hasNavigated) {
      return;
    }

    _hasNavigated = true;

    Routes.navigateToDashboard(context);
  }

  Future<void> _handleUnauthenticatedBoot() async {
    try {
      _updateProgress(
        step: 'Offline Setup',
        message: 'Preparing offline mode...',
        value: 0.72,
      );

      await RemindersManager.instance.rescheduleAllCropReminders();

      debugPrint('✅ Offline crop reminders restored');
    } catch (e) {
      debugPrint('Error restoring reminders offline: $e');
    }

    _updateProgress(
      step: 'Login',
      message: 'Redirecting to login...',
      value: 0.96,
    );

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted || _hasNavigated) {
      return;
    }

    _hasNavigated = true;

    Routes.navigateToLogin(context);
  }

  Future<bool> _hasStoredTokens() async {
    try {
      final accessToken = await storage.read(key: 'access_token');

      final refreshToken = await storage.read(key: 'refresh_token');

      final hasTokens =
          accessToken != null &&
          accessToken.isNotEmpty &&
          refreshToken != null &&
          refreshToken.isNotEmpty;

      debugPrint('Token check: ${hasTokens ? 'Found' : 'Not found'}');

      return hasTokens;
    } catch (e) {
      debugPrint('Error checking tokens: $e');

      return false;
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

    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F1DF), Color(0xFFF5F4EC), Color(0xFFE3EED7)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Stack(
              children: [
                _buildBackgroundGlow(),
                _buildFloatingLeaves(),
                _buildBottomLandscape(),
                _buildTextVisibilityOverlay(),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: isSmallScreen ? 18 : 28,
                    ),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        _buildLogo(isSmallScreen),
                        SizedBox(height: isSmallScreen ? 20 : 26),
                        _buildTitle(),
                        const SizedBox(height: 10),
                        _buildSubtitleText(),
                        const SizedBox(height: 22),
                        _buildDecorativeDivider(),
                        const Spacer(flex: 3),
                        _buildStatusSection(),
                        SizedBox(height: isSmallScreen ? 28 : 36),
                      ],
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

  Widget _buildLogo(bool isSmallScreen) {
    final logoSize = isSmallScreen ? 148.0 : 176.0;

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: logoSize,
        height: logoSize,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.34),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8FAE73).withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'AGRHI',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: _scaleText(context, 50),
        fontWeight: FontWeight.w900,
        color: const Color(0xFF3F742F),
        letterSpacing: 2.6,
        height: 1.0,
        shadows: _softTextShadow,
      ),
    );
  }

  Widget _buildSubtitleText() {
    return Text(
      'Smart Farm Assistant',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: _scaleText(context, 17),
        color: const Color(0xFF4F7843),
        fontWeight: FontWeight.w800,
        letterSpacing: 0.9,
        height: 1.25,
        shadows: _softTextShadow,
      ),
    );
  }

  Widget _buildDecorativeDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 62,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFFAEC78A).withOpacity(0.90),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 14),
        const Icon(Icons.eco_rounded, color: Color(0xFF5F8B49), size: 24),
        const SizedBox(width: 14),
        Container(
          width: 62,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFFAEC78A).withOpacity(0.90),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: _progressValue),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            final percent = (value * 100).round();

            return Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.16),
                border: Border.all(
                  color: const Color(0xFFD5E4BF).withOpacity(0.95),
                  width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8DAE72).withOpacity(0.14),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: const Color(0xFFDDE8CC),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4D873C),
                      ),
                      semanticsLabel: 'Splash loading progress',
                      semanticsValue: '$percent%',
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: _scaleText(context, 24),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF3F742F),
                          height: 1.0,
                          shadows: _softTextShadow,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Loading',
                        style: TextStyle(
                          fontSize: _scaleText(context, 11),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF6F8D62),
                          letterSpacing: 0.8,
                          shadows: _softTextShadow,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.18),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            _progressName,
            key: ValueKey(_progressName),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _scaleText(context, 18),
              color: const Color(0xFF3F742F),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.35,
              shadows: _softTextShadow,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Padding(
            key: ValueKey(_statusMessage),
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _scaleText(context, 14.5),
                color: const Color(0xFF587B4D),
                fontWeight: FontWeight.w700,
                height: 1.4,
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity(0.42),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: 190,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.42),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _progressValue),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF83B85B), Color(0xFF4D873C)],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6A9A4E).withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_showOfflineBadge) ...[
          const SizedBox(height: 14),
          _buildOfflineBadge(),
        ],
      ],
    );
  }

  Widget _buildOfflineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFE3C66F).withOpacity(0.85),
          width: 1.2,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFFC28A1B)),
          SizedBox(width: 8),
          Text(
            'Offline Mode',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFC28A1B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlow() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFCFE3AE).withOpacity(0.24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCFE3AE).withOpacity(0.34),
                      blurRadius: 90,
                      spreadRadius: 28,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 90,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF3E7B2).withOpacity(0.18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF3E7B2).withOpacity(0.25),
                      blurRadius: 80,
                      spreadRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingLeaves() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: 88,
              left: -4,
              child: Transform.rotate(
                angle: -0.7,
                child: Icon(
                  Icons.eco_rounded,
                  size: 74,
                  color: const Color(0xFF9ABB6C).withOpacity(0.42),
                ),
              ),
            ),
            Positioned(
              top: 270,
              right: 36,
              child: Transform.rotate(
                angle: 0.5,
                child: Icon(
                  Icons.eco_rounded,
                  size: 50,
                  color: const Color(0xFF88AC58).withOpacity(0.52),
                ),
              ),
            ),
            Positioned(
              top: 430,
              left: 26,
              child: Transform.rotate(
                angle: -0.9,
                child: Icon(
                  Icons.eco_rounded,
                  size: 46,
                  color: const Color(0xFF8FB55A).withOpacity(0.55),
                ),
              ),
            ),
            Positioned(
              bottom: 68,
              right: 18,
              child: Transform.rotate(
                angle: 0.8,
                child: Icon(
                  Icons.eco_rounded,
                  size: 84,
                  color: const Color(0xFFA8C86E).withOpacity(0.44),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomLandscape() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.34,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/dashboard_bg.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFEAF3E1).withOpacity(0.94),
                      const Color(0xFFEAF3E1).withOpacity(0.08),
                      const Color(0xFFEAF3E1).withOpacity(0.12),
                    ],
                    stops: const [0.0, 0.38, 1.0],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 82,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFFE7F0DD),
                        const Color(0xFFE7F0DD).withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextVisibilityOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFEAF3E1).withOpacity(0.18),
                const Color(0xFFF7F5EE).withOpacity(0.52),
                const Color(0xFFF7F5EE).withOpacity(0.68),
                const Color(0xFFE7F0DD).withOpacity(0.34),
              ],
              stops: const [0.0, 0.28, 0.65, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
