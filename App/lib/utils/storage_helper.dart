// lib/src/utils/storage_helper.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageHelper {
  // Singleton pattern - ensure only one configured instance
  static final StorageHelper _instance = StorageHelper._internal();
  factory StorageHelper() => _instance;
  StorageHelper._internal();

  // Properly configured storage instance
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  /// Read with retry mechanism
  Future<String?> read(String key, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final value = await _storage.read(key: key);
        if (value != null && value.isNotEmpty) {
          return value;
        }
        // Wait before retry
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
        }
      } catch (e) {
        print('❌ Storage read attempt ${i + 1} failed for $key: $e');
        if (i == maxRetries - 1) rethrow;
      }
    }
    return null;
  }

  /// Write to storage
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Delete from storage
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Delete all
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// Read all items
  Future<Map<String, String>> readAll() async {
    return await _storage.readAll();
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    return await read('access_token');
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await read('refresh_token');
  }

  /// Get user profile
  Future<String?> getUserProfile() async {
    return await read('user_profile');
  }

  /// Get user id from profile
  Future<String?> getUserId() async {
    final profileJson = await getUserProfile();
    if (profileJson != null) {
      try {
        final profileMap = Map<String, dynamic>.from(
          jsonDecode(profileJson) as Map<String, dynamic>,
        );
        return profileMap['user_id'] as String?;
      } catch (e) {
        print('❌ Failed to parse user profile JSON: $e');
      }
    }
    return null;
  }
}
