// lib/src/screens/splash/splash_screen.dart
import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../utils/routes.dart';
import '../../src/services/auth_service.dart';

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

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkAuthAndNavigate();
  }

  void _setupAnimations() {
    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Pulse animation for loading indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() => _statusMessage = 'Checking authentication...');
    await Future.delayed(const Duration(milliseconds: 500));

    final authStatus = await _authService.checkAuthStatus();

    if (!mounted) return;

    switch (authStatus) {
      case AuthStatus.authenticated:
        setState(() => _statusMessage = 'Welcome back!');
        await Future.delayed(const Duration(milliseconds: 500));
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

                  // Logo - simple and clean
                  _buildLogo(isSmallScreen),

                  SizedBox(height: isSmallScreen ? 32 : 40),

                  // App Title
                  _buildTitle(),

                  SizedBox(height: isSmallScreen ? 12 : 16),

                  // Subtitle badge
                  _buildSubtitle(),

                  const Spacer(flex: 4),

                  // Status section
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
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
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
        // Offline badge
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

        // Status message
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

        // Loading indicator
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
