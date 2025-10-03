import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';

class Routes {
  // Route names
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String home = '/'; // Alternative home route

  // Route definitions
  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginScreen(),
    signup: (context) => const SignupScreen(),
    dashboard: (context) => const DashboardScreen(),
    home: (context) => const LoginScreen(), // Default to login
  };

  // Navigation helper methods
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

  // Push replacement methods
  static void pushReplacementToDashboard(BuildContext context) {
    Navigator.pushReplacementNamed(context, dashboard);
  }

  static void pushReplacementToLogin(BuildContext context) {
    Navigator.pushReplacementNamed(context, login);
  }

  // Pop and push methods
  static void popAndPushToDashboard(BuildContext context) {
    Navigator.popAndPushNamed(context, dashboard);
  }

  // Check if can pop
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  // Pop to root
  static void popToRoot(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}
