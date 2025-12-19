import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/shared/splash_screen.dart';
import 'utils/colors.dart';
import 'utils/routes.dart';
import 'src/services/language_service.dart';
import 'src/services/model_manager_provider.dart';
import 'src/services/connectivity_manager.dart';
import 'src/database/database_helper.dart';

void main() async {
  // ✅ Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Lock orientation to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ✅ Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ✅ Initialize services with better error handling
  bool initSuccess = true;

  try {
    // Initialize Hive for caching
    await Hive.initFlutter();
    await Hive.openBox('translation_cache');
    debugPrint('✅ Hive cache initialized successfully.');
  } catch (e, stackTrace) {
    debugPrint('❌ Hive initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');
    initSuccess = false;
  }

  try {
    // Initialize SQLite database
    await DatabaseHelper.instance.database;
    debugPrint('✅ Database initialized successfully.');
  } catch (e, stackTrace) {
    debugPrint('❌ Database initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');
    initSuccess = false;
  }

  try {
    // Initialize connectivity manager (singleton, no await needed)
    ConnectivityManager.instance;
    debugPrint('✅ Connectivity manager initialized.');
  } catch (e, stackTrace) {
    debugPrint('❌ Connectivity manager initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');
  }

  if (!initSuccess) {
    debugPrint('⚠️ App starting with partial initialization');
  }

  // ✅ Handle global Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('❌ Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // ✅ Handle errors outside of Flutter framework
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('❌ Platform Error: $error');
    debugPrint('Stack trace: $stack');
    return true; // Return true to indicate error was handled
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ✅ Language Service
        ChangeNotifierProvider(create: (_) => LanguageService()),

        // ✅ Model Manager
        ChangeNotifierProvider(create: (_) => ModelManagerProvider()),

        // ✅ Connectivity Manager (singleton)
        ChangeNotifierProvider<ConnectivityManager>.value(
          value: ConnectivityManager.instance,
        ),
      ],
      child: Consumer<LanguageService>(
        builder: (context, languageService, _) {
          return MaterialApp(
            title: 'AGRHI - Smart Farming Solutions',
            debugShowCheckedModeBanner: false,

            // ✅ Theme Configuration
            theme: ThemeData(
              useMaterial3: true,

              // Primary color
              primarySwatch:
                  MaterialColor(AppColors.primaryGreen.value, <int, Color>{
                    50: AppColors.primaryGreen.withOpacity(0.1),
                    100: AppColors.primaryGreen.withOpacity(0.2),
                    200: AppColors.primaryGreen.withOpacity(0.3),
                    300: AppColors.primaryGreen.withOpacity(0.4),
                    400: AppColors.primaryGreen.withOpacity(0.5),
                    500: AppColors.primaryGreen.withOpacity(0.6),
                    600: AppColors.primaryGreen.withOpacity(0.7),
                    700: AppColors.primaryGreen.withOpacity(0.8),
                    800: AppColors.primaryGreen.withOpacity(0.9),
                    900: AppColors.primaryGreen,
                  }),

              // Color scheme for Material 3
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryGreen,
                brightness: Brightness.light,
              ),

              // Typography
              fontFamily: 'Roboto',

              textTheme: const TextTheme(
                displayLarge: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                titleLarge: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                bodyLarge: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
                bodyMedium: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),

              // AppBar theme
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.textWhite,
                elevation: 2,
                shadowColor: AppColors.shadowColor,
                centerTitle: false,
                titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textWhite,
                  letterSpacing: 0.15,
                ),
              ),

              // Button themes
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.textWhite,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Input decoration theme
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.errorColor),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.errorColor,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),

              // Card theme
              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),

              // SnackBar theme
              snackBarTheme: SnackBarThemeData(
                backgroundColor: Colors.grey.shade800,
                contentTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                behavior: SnackBarBehavior.floating,
              ),

              // Dialog theme
              dialogTheme: DialogThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
              ),

              // Bottom sheet theme
              bottomSheetTheme: const BottomSheetThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                elevation: 8,
              ),
            ),

            // Navigation
            initialRoute: Routes.splash,
            routes: Routes.routes,

            // Error handling
            onUnknownRoute: (settings) {
              debugPrint('⚠️ Unknown route: ${settings.name}');
              return MaterialPageRoute(builder: (_) => const SplashScreen());
            },

            // Route debugging
            onGenerateRoute: (settings) {
              debugPrint('📍 Navigating to: ${settings.name}');
              return null;
            },

            // Builder for global overlays/error handling
            builder: (context, child) {
              // ✅ Prevent text scaling beyond reasonable limits
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: MediaQuery.of(
                    context,
                  ).textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 1.3),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
