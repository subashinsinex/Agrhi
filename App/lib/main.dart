import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'src/services/navigation_service.dart';
import 'src/services/notification_service.dart';
import 'screens/shared/splash_screen.dart';
import 'utils/colors.dart';
import 'utils/routes.dart';
import 'src/services/language_service.dart';
import 'src/services/model_manager_provider.dart';
import 'src/services/connectivity_manager.dart';
import 'src/database/database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  bool initSuccess = true;
  String? initialNotificationPayload;

  try {
    await Hive.initFlutter();
    await Hive.openBox('translation_cache');
    debugPrint('✅ Hive cache initialized successfully.');
  } catch (e, stackTrace) {
    debugPrint('❌ Hive initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');
    initSuccess = false;
  }

  try {
    await DatabaseHelper.instance.database;
    debugPrint('✅ Database initialized successfully.');
  } catch (e, stackTrace) {
    debugPrint('❌ Database initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');
    initSuccess = false;
  }

  try {
    ConnectivityManager.instance;
    debugPrint('✅ Connectivity manager initialized.');
  } catch (e, stackTrace) {
    debugPrint('❌ Connectivity manager initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');
  }

  try {
    await NotificationService.initialize();

    await NotificationService.debugPendingNotifications();

    final notificationAppLaunchDetails = await NotificationService.plugin
        .getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      initialNotificationPayload =
          notificationAppLaunchDetails?.notificationResponse?.payload;

      debugPrint(
        'AGRHI_NOTIFICATION_LAUNCH payload: $initialNotificationPayload',
      );
    }

    debugPrint('✅ Notifications initialized successfully.');
  } catch (e, stackTrace) {
    debugPrint('❌ Notification initialization failed: $e');
    debugPrint('Stack trace: $stackTrace');
    initSuccess = false;
  }

  if (!initSuccess) {
    debugPrint('⚠️ App starting with partial initialization');
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('❌ Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('❌ Platform Error: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };

  runApp(MyApp(initialNotificationPayload: initialNotificationPayload));
}

class MyApp extends StatelessWidget {
  final String? initialNotificationPayload;

  const MyApp({super.key, this.initialNotificationPayload});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageService()),
        ChangeNotifierProvider(create: (_) => ModelManagerProvider()),
        ChangeNotifierProvider<ConnectivityManager>.value(
          value: ConnectivityManager.instance,
        ),
      ],
      child: Consumer<LanguageService>(
        builder: (context, languageService, _) {
          return MaterialApp(
            navigatorKey: NavigationService.navigatorKey,
            title: 'AGRHI - Smart Farming Assistant',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
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
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryGreen,
                brightness: Brightness.light,
              ),
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
              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
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
              dialogTheme: DialogThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
              ),
              bottomSheetTheme: const BottomSheetThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                elevation: 8,
              ),
            ),
            home: SplashScreen(
              initialNotificationPayload: initialNotificationPayload,
            ),
            routes: Routes.routes,
            onUnknownRoute: (settings) {
              debugPrint('⚠️ Unknown route: ${settings.name}');
              return MaterialPageRoute(builder: (_) => const SplashScreen());
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
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
