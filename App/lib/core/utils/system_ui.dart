import 'package:flutter/services.dart';

/// Let the app paint behind system bars; only control icon appearance here.
/// Bar-color APIs are deprecated on Android 15 and newer.
abstract final class AppSystemUi {
  static const overlayStyle = SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.dark,
  );
}
