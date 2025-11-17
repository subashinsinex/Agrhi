import 'package:flutter/material.dart';
import '../screens/shared/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/features/dashboard_screen.dart';
import '../screens/features/model_manager_screen.dart'; // ADD THIS

class Routes {
  // Route names
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String modelManager = '/model-manager'; // ADD THIS
  static const String home = '/'; // Alternative home route

  // Route definitions
  static Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    signup: (context) => const SignupScreen(),
    dashboard: (context) => const DashboardScreen(),
    modelManager: (context) => const ModelManagerScreen(), // ADD THIS
    home: (context) => const SplashScreen(), // Default to splash
  };

  // Navigation helper methods
  static void navigateToSplash(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      splash,
      (Route<dynamic> route) => false,
    );
  }

  static void navigateToLogin(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      login,
      (Route<dynamic> route) => false,
    );
  }

  static void navigateToDashboard(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      dashboard,
      (Route<dynamic> route) => false,
    );
  }

  static void navigateToSignup(BuildContext context) {
    Navigator.pushNamed(context, signup);
  }

  // ADD THIS: Navigation helper for Model Manager
  static void navigateToModelManager(BuildContext context) {
    Navigator.pushNamed(context, modelManager);
  }

  // Push replacement methods
  static void pushReplacementToDashboard(BuildContext context) {
    Navigator.pushReplacementNamed(context, dashboard);
  }

  static void pushReplacementToLogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, login);
  }

  static void pushReplacementToSplash(BuildContext context) {
    Navigator.pushReplacementNamed(context, splash);
  }

  // Pop and push methods
  static void popAndPushToDashboard(BuildContext context) {
    Navigator.popAndPushNamed(context, dashboard);
  }

  static void popAndPushToLogin(BuildContext context) {
    Navigator.popAndPushNamed(context, login);
  }

  // Check if can pop
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  // Pop to root
  static void popToRoot(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // Pop with optional result
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.pop(context, result);
  }
}
