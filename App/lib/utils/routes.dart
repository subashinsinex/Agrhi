import 'package:flutter/material.dart';
import '../screens/shared/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/features/dashboard_screen.dart';
import '../screens/features/disease_detection/model_manager_screen.dart';

class Routes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String modelManager = '/model-manager';

  static Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    signup: (context) => const SignupScreen(),
    dashboard: (context) => const DashboardScreen(),
    modelManager: (context) => const ModelManagerScreen(),
  };

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
}
