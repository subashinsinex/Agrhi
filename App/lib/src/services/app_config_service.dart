// lib/src/services/app_config_service.dart
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class AppConfigService {
  static const String baseUrl = AppConstants.baseUrl;

  // ✅ Send app info to server, get instructions back
  static Future<Map<String, dynamic>?> checkAppConfig() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      // ✅ SEND APP INFO TO SERVER
      final response = await http
          .post(
            Uri.parse('$baseUrl/developer/config'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'build_number': packageInfo.buildNumber,
              'platform': Platform.isAndroid ? 'android' : 'ios',
              'package_name': packageInfo.packageName,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final config = jsonDecode(response.body);
        debugPrint('✅ Server says: $config');

        // ✅ SERVER TOLD US WHAT TO DO
        return config;
      } else {
        debugPrint('⚠️ Server check failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error checking with server: $e');
      return null;
    }
  }
}
