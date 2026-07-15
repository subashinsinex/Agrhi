// lib/src/services/app_config_service.dart

import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'api_service.dart';

class AppConfigService {
  static Future<Map<String, dynamic>?> checkAppConfig() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await ApiService.instance.post(
        '/developer/config',
        body: {
          'build_number': packageInfo.buildNumber,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'package_name': packageInfo.packageName,
        },
        timeout: const Duration(seconds: 10),
        requiresAuth: false,
      );
      if (response.isSuccess) {
        debugPrint('✅ Server says: ${response.data}');
        return response.data as Map<String, dynamic>?;
      } else if (response.isOffline) {
        debugPrint('⚠️ Offline - skipping config check');
        return null;
      } else {
        debugPrint('⚠️ Server check failed: ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error checking with server: $e');
      return null;
    }
  }
}
