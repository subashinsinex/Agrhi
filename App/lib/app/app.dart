import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:agrhi/core/utils/system_ui.dart';
import 'package:provider/provider.dart';

import 'package:agrhi/services/navigation_service.dart';
import 'package:agrhi/views/shared/splash_screen.dart';
import 'package:agrhi/core/utils/colors.dart';
import 'package:agrhi/core/utils/routes.dart';
import 'package:agrhi/controllers/language_controller.dart';
import 'package:agrhi/controllers/model_manager_controller.dart';
import 'package:agrhi/controllers/connectivity_controller.dart';

import 'package:agrhi/core/utils/page_transitions.dart';

class MyApp extends StatelessWidget {
  final String? initialNotificationPayload;

  const MyApp({super.key, this.initialNotificationPayload});

  static const Color brandPrimary = Color(0xFF00FFAB);
  static const Color brandSecondary = Color(0xFF14C38E);
  static const Color brandAccent = Color(0xFFB8F1B0);
  static const Color brandHighlight = Color(0xFFE3FCBF);

  static const Color textPrimaryModern = Color(0xFF083B2E);
  static const Color textSecondaryModern = Color(0xFF4C6B61);

  @override
  Widget build(BuildContext context) {
    final MaterialColor modernSwatch =
        MaterialColor(brandSecondary.value, <int, Color>{
          50: brandSecondary.withOpacity(0.10),
          100: brandSecondary.withOpacity(0.20),
          200: brandSecondary.withOpacity(0.30),
          300: brandSecondary.withOpacity(0.40),
          400: brandSecondary.withOpacity(0.50),
          500: brandSecondary.withOpacity(0.60),
          600: brandSecondary.withOpacity(0.70),
          700: brandSecondary.withOpacity(0.80),
          800: brandSecondary.withOpacity(0.90),
          900: brandSecondary,
        });

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageController()),
        ChangeNotifierProvider(create: (_) => ModelManagerController()),
        ChangeNotifierProvider<ConnectivityController>.value(
          value: ConnectivityController.instance,
        ),
      ],
      child: Consumer<LanguageController>(
        builder: (context, languageService, _) {
          return MaterialApp(
            navigatorKey: NavigationService.navigatorKey,
            title: 'AGRHI - Smart Farming Assistant',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              primarySwatch: modernSwatch,
              scaffoldBackgroundColor: Colors.transparent,
              canvasColor: Colors.transparent,
              splashFactory: InkSparkle.splashFactory,
              colorScheme: ColorScheme.fromSeed(
                seedColor: brandSecondary,
                brightness: Brightness.light,
                primary: brandSecondary,
                secondary: brandPrimary,
                tertiary: brandAccent,
                background: brandHighlight,
                surface: Colors.white.withOpacity(0.88),
              ),
              fontFamily: 'Roboto',
              textTheme: const TextTheme(
                displayLarge: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: textPrimaryModern,
                  letterSpacing: -0.5,
                ),
                displayMedium: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: textPrimaryModern,
                ),
                titleLarge: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimaryModern,
                ),
                titleMedium: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryModern,
                ),
                bodyLarge: TextStyle(
                  fontSize: 16,
                  color: textPrimaryModern,
                  height: 1.5,
                ),
                bodyMedium: TextStyle(
                  fontSize: 14,
                  color: textSecondaryModern,
                  height: 1.45,
                ),
                bodySmall: TextStyle(
                  fontSize: 12,
                  color: textSecondaryModern,
                  height: 1.35,
                ),
                labelLarge: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryModern,
                ),
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.transparent,
                foregroundColor: textPrimaryModern,
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                centerTitle: false,
                systemOverlayStyle: AppSystemUi.overlayStyle,
                titleTextStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textPrimaryModern,
                  letterSpacing: 0.1,
                ),
                iconTheme: const IconThemeData(
                  color: textPrimaryModern,
                  size: 22,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandSecondary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: brandPrimary,
                  foregroundColor: textPrimaryModern,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimaryModern,
                  side: BorderSide(color: brandSecondary.withOpacity(0.28)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white.withOpacity(0.82),
                hintStyle: const TextStyle(
                  color: textSecondaryModern,
                  fontSize: 14,
                ),
                labelStyle: const TextStyle(
                  color: textPrimaryModern,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: brandAccent.withOpacity(0.25)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: brandAccent.withOpacity(0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: brandSecondary,
                    width: 1.6,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: AppColors.errorColor,
                    width: 1.2,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: AppColors.errorColor,
                    width: 1.6,
                  ),
                ),
              ),
              cardTheme: CardThemeData(
                color: Colors.white.withOpacity(0.75),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.65),
                    width: 1,
                  ),
                ),
              ),
              snackBarTheme: SnackBarThemeData(
                backgroundColor: textPrimaryModern,
                contentTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                behavior: SnackBarBehavior.floating,
                elevation: 0,
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: Colors.white.withOpacity(0.95),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              bottomSheetTheme: BottomSheetThemeData(
                backgroundColor: Colors.white.withOpacity(0.96),
                surfaceTintColor: Colors.transparent,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                elevation: 0,
              ),
              dividerColor: Colors.white.withOpacity(0.72),
              iconTheme: const IconThemeData(color: textPrimaryModern),
            ),
            home: SplashScreen(
              initialNotificationPayload: initialNotificationPayload,
            ),
            routes: Routes.routes,
            onUnknownRoute: (settings) {
              debugPrint('⚠️ Unknown route: ${settings.name}');

              return smoothPageRoute(
                SplashScreen(
                  initialNotificationPayload: initialNotificationPayload,
                ),
              );
            },
            onGenerateRoute: (settings) {
              debugPrint('📍 Navigating to: ${settings.name}');
              return null;
            },
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: MediaQuery.of(
                    context,
                  ).textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 1.3),
                ),
                child: AppGradientBackground(
                  // Paint to the screen edges while keeping route controls
                  // clear of navigation bars and side display cutouts.
                  child: SafeArea(
                    top: false, // App bars/screens own their top inset.
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AppGradientBackground extends StatelessWidget {
  final Widget child;

  const AppGradientBackground({super.key, required this.child});

  static const Color brandSecondary = Color(0xFF00FFAB);
  static const Color brandPrimary = Color(0xFF14C38E);
  static const Color brandAccent = Color(0xFFB8F1B0);
  static const Color brandHighlight = Color(0xFFE3FCBF);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brandPrimary, brandSecondary, brandAccent, brandHighlight],
          stops: [0.0, 0.28, 0.70, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -90,
            left: -50,
            child: _BlurOrb(size: 230, color: brandPrimary.withOpacity(0.24)),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: _BlurOrb(size: 260, color: brandSecondary.withOpacity(0.24)),
          ),
          Positioned(
            bottom: -80,
            left: 20,
            child: _BlurOrb(size: 220, color: brandAccent.withOpacity(0.28)),
          ),
          Positioned(
            bottom: 40,
            right: -30,
            child: _BlurOrb(size: 180, color: brandHighlight.withOpacity(0.22)),
          ),
          Positioned.fill(
            child: Container(color: Colors.white.withOpacity(0.03)),
          ),
          child,
        ],
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 46, sigmaY: 46),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
