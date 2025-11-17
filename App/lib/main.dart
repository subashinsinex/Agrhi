import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/shared/splash_screen.dart';
import 'utils/colors.dart';
import 'utils/routes.dart';
import 'src/services/language_service.dart';
import 'src/services/model_manager_provider.dart';
import 'src/database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await DatabaseHelper.instance.database;
  print('✅ Database initialized successfully.');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LanguageService()),
        ChangeNotifierProvider(create: (context) => ModelManagerProvider()),
      ],
      child: Consumer<LanguageService>(
        builder: (context, languageService, child) {
          return MaterialApp(
            title: 'AGRHI - Smart Farming Solutions',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
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
              fontFamily: 'Roboto',
              appBarTheme: AppBarTheme(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.textWhite,
                elevation: 8,
                shadowColor: AppColors.shadowColor,
                centerTitle: false,
                titleTextStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textWhite,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.textWhite,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                  borderSide: BorderSide(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.errorColor),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            initialRoute: Routes.splash,
            routes: Routes.routes,
            onUnknownRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => const SplashScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
