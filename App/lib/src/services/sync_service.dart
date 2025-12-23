// lib/src/services/sync_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/database_helper.dart';
import '../../utils/constants.dart';
import 'api_service.dart';

/// Service for two-way sync of disease analysis, images, and profile
class SyncService {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  final DatabaseHelper _db = DatabaseHelper.instance;
  static const String baseUrl = AppConstants.baseUrl;

  // ✅ Sync lock to prevent duplicate syncs
  bool _isSyncing = false;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  // ================= FULL SYNC =================

  /// Perform full sync: catalogs + analyses + images + profile
  Future<Map<String, dynamic>> performFullSync(String accessToken) async {
    // ✅ Check if already syncing
    if (_isSyncing) {
      debugPrint('⏭️ Disease sync already in progress - skipping');
      return {
        'success': false,
        'error': 'Sync already in progress',
        'skipped': true,
      };
    }

    _isSyncing = true; // ✅ Lock sync

    try {
      debugPrint('🔄 Starting full sync...');

      // Step 1: Sync catalogs (diseases, remedies, plants, etc.)
      final catalogResult = await _db.smartSyncCatalogs(accessToken);

      // Step 2: Two-way sync for analyses and images
      final twoWayResult = await performTwoWaySync(accessToken);

      // Step 3: Sync profile based on updated_at
      await _syncProfileIfNeeded();

      final success = catalogResult['success'] && twoWayResult['success'];

      if (success) {
        debugPrint('✅ Disease analysis sync completed');
      }

      return {
        'success': success,
        'catalogs': catalogResult,
        'two_way_sync': twoWayResult,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Full sync error: $e');
      return {'success': false, 'error': e.toString()};
    } finally {
      _isSyncing = false; // ✅ Unlock sync
    }
  }

  // ================= PROFILE SYNC =================

  /// Sync profile if server updated_at is newer than local
  Future<void> _syncProfileIfNeeded() async {
    try {
      // 1. Read local profile and updated_at
      final profileJson = await _storage.read(key: 'user_profile');
      String? localUpdatedAt;

      if (profileJson != null && profileJson.isNotEmpty) {
        final profileData = jsonDecode(profileJson) as Map<String, dynamic>;
        localUpdatedAt = profileData['updated_at']?.toString();
      }

      // 2. Get user id
      final userId = await _storage.read(key: 'user_id');
      if (userId == null) {
        debugPrint('⚠️ Profile sync skipped: user_id missing');
        return;
      }

      // 3. Call profile details endpoint
      final response = await ApiService.instance.get(
        '/profile/getUserDetails/$userId',
        requiresAuth: true,
        timeout: const Duration(seconds: 30),
      );

      debugPrint('📡 Profile sync response: ${response.statusCode}');

      if (!(response.isSuccess || response.statusCode == 200)) {
        debugPrint('⚠️ Profile sync failed: ${response.error}');
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final serverUpdatedAt = data['updated_at']?.toString();

      if (serverUpdatedAt == null) {
        debugPrint('⚠️ Profile sync: server updated_at missing');
        return;
      }

      // 4. Compare timestamps
      if (localUpdatedAt == null ||
          DateTime.parse(
            serverUpdatedAt,
          ).isAfter(DateTime.parse(localUpdatedAt))) {
        await _storage.write(key: 'user_profile', value: jsonEncode(data));
        debugPrint('✅ Profile synced from server (updated_at newer)');
      } else {
        debugPrint('ℹ️ Profile up to date, no sync needed');
      }
    } catch (e) {
      debugPrint('⚠️ Profile sync error: $e');
    }
  }

  // ================= TWO-WAY SYNC FOR DISEASE ANALYSIS =================

  /// Complete two-way sync: push local changes, then pull server updates
  Future<Map<String, dynamic>> performTwoWaySync(String accessToken) async {
    try {
      debugPrint('🔄 Starting two-way sync...');

      // Step 1: Push local changes to server (upload pending analyses)
      final uploadResult = await uploadPendingAnalyses(accessToken);

      // Step 2: Pull server updates (download new/changed analyses)
      final downloadResult = await downloadServerAnalyses(accessToken);

      // Step 3: Upload local images that haven't been uploaded
      final imageUploadResult = await syncImages(accessToken);

      // Step 4: Download server images that don't exist locally
      final imageDownloadResult = await downloadServerImages(accessToken);

      final allSuccess =
          uploadResult['success'] &&
          downloadResult['success'] &&
          imageUploadResult['success'] &&
          imageDownloadResult['success'];

      return {
        'success': allSuccess,
        'upload': uploadResult,
        'download': downloadResult,
        'image_upload': imageUploadResult,
        'image_download': imageDownloadResult,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Two-way sync error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= UPLOAD (PUSH LOCAL TO SERVER) =================

  /// Upload pending disease analyses to server as JSON batch
  Future<Map<String, dynamic>> uploadPendingAnalyses(String accessToken) async {
    try {
      final pending = await _db.getPendingAnalyses();
      debugPrint('📤 Uploading ${pending.length} pending analyses...');

      if (pending.isEmpty) {
        return {
          'success': true,
          'message': 'No pending analyses',
          'uploaded': 0,
        };
      }

      final analysesToUpload = <Map<String, dynamic>>[];

      for (final analysis in pending) {
        analysesToUpload.add({
          'id': analysis['id'],
          'user_id': analysis['user_id'],
          'plant_id': analysis['plant_id'],
          'image_id': analysis['image_id'],
          'disease_id': analysis['disease_id'],
          'confidence': analysis['confidence'],
          'created_at': analysis['created_at'],
        });
      }

      // ✅ USE ApiService
      final response = await ApiService.instance.post(
        '/sync/batch-upload',
        body: {'analyses': analysesToUpload},
        requiresAuth: true,
      );

      debugPrint('📡 Upload response: ${response.statusCode}');

      if (response.isSuccess) {
        final responseData = response.data;
        final uploadedIds =
            (responseData['uploaded_ids'] as List?)
                ?.map((id) => id.toString())
                .toList() ??
            [];

        // Mark uploaded analyses as synced
        for (final id in uploadedIds) {
          await _db.markAsUploaded(id, null);
        }

        debugPrint('✅ Uploaded ${uploadedIds.length} analyses');

        return {
          'success': true,
          'uploaded': uploadedIds.length,
          'uploaded_ids': uploadedIds,
        };
      }

      debugPrint('❌ Upload failed: ${response.statusCode}');
      debugPrint('Response error: ${response.error}');
      return {
        'success': false,
        'message': 'Upload failed: ${response.error}',
        'uploaded': 0,
      };
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return {'success': false, 'error': e.toString(), 'uploaded': 0};
    }
  }

  // ================= DOWNLOAD (PULL FROM SERVER) =================

  /// Download disease analyses from server as JSON
  Future<Map<String, dynamic>> downloadServerAnalyses(
    String accessToken, {
    String? since,
  }) async {
    try {
      final lastSync = since ?? await _getLastSyncTimestamp();

      debugPrint('📥 Downloading analyses since: ${lastSync ?? "beginning"}');

      // ✅ USE ApiService
      final response = await ApiService.instance.get(
        '/sync/changes',
        queryParams: lastSync != null ? {'since': lastSync} : null,
        requiresAuth: true,
      );

      debugPrint('📡 Download response: ${response.statusCode}');

      if (response.isSuccess) {
        final data = response.data;
        final analyses =
            (data['analyses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final deletedIds =
            (data['deleted_ids'] as List?)
                ?.map((id) => id.toString())
                .toList() ??
            [];

        debugPrint(
          '📦 Received ${analyses.length} analyses, ${deletedIds.length} deletions',
        );

        // Apply server changes locally
        await _applyServerChanges(analyses, deletedIds);

        // Update sync timestamp in secure storage
        await _updateLastSyncTimestamp(data['server_timestamp']);

        return {
          'success': true,
          'downloaded': analyses.length,
          'deleted': deletedIds.length,
        };
      }

      debugPrint('❌ Download failed: ${response.statusCode}');
      debugPrint('Response error: ${response.error}');
      return {
        'success': false,
        'message': 'Download failed: ${response.error}',
        'downloaded': 0,
        'deleted': 0,
      };
    } catch (e) {
      debugPrint('❌ Download error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'downloaded': 0,
        'deleted': 0,
      };
    }
  }

  /// Apply server changes to local database
  Future<void> _applyServerChanges(
    List<Map<String, dynamic>> analyses,
    List<String> deletedIds,
  ) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      // Apply analyses from server
      for (final analysis in analyses) {
        // Handle image if present
        if (analysis['image_id'] != null) {
          final imageExists = await txn.query(
            'images',
            where: 'image_id = ?',
            whereArgs: [analysis['image_id']],
            limit: 1,
          );

          final serverImageUrl = analysis['server_image_url'] as String?;

          // Check: Is this a placeholder URL or real URL?
          final isPlaceholder =
              serverImageUrl == null ||
              serverImageUrl == '/uploads/images/pending' ||
              serverImageUrl.isEmpty;

          if (imageExists.isEmpty) {
            // Insert new image record
            await txn.insert('images', {
              'image_id': analysis['image_id'],
              'local_path': '',
              'server_image_url': serverImageUrl,
              'is_uploaded': isPlaceholder ? 0 : 1,
            });
            debugPrint(
              '📥 Created image record: ${analysis['image_id']} (uploaded: ${!isPlaceholder})',
            );
          } else {
            // Update existing image record
            final existingLocalPath =
                imageExists.first['local_path'] as String?;

            await txn.update(
              'images',
              {
                'server_image_url': serverImageUrl,
                'is_uploaded': isPlaceholder ? 0 : 1,
                if (existingLocalPath != null && existingLocalPath.isNotEmpty)
                  'local_path': existingLocalPath,
              },
              where: 'image_id = ?',
              whereArgs: [analysis['image_id']],
            );
            debugPrint(
              '📥 Updated image record: ${analysis['image_id']} (uploaded: ${!isPlaceholder})',
            );
          }
        }

        // Handle analysis
        final exists = await txn.query(
          'disease_analysis_results',
          where: 'id = ?',
          whereArgs: [analysis['id']],
          limit: 1,
        );

        if (exists.isEmpty) {
          await txn.insert('disease_analysis_results', {
            'id': analysis['id'],
            'user_id': analysis['user_id'],
            'plant_id': analysis['plant_id'],
            'image_id': analysis['image_id'],
            'disease_id': analysis['disease_id'],
            'confidence': analysis['confidence'],
            'created_at': analysis['created_at'],
            'is_uploaded': 1,
            'is_dirty': 0,
          });
        } else {
          await txn.update(
            'disease_analysis_results',
            {
              'user_id': analysis['user_id'],
              'plant_id': analysis['plant_id'],
              'image_id': analysis['image_id'],
              'disease_id': analysis['disease_id'],
              'confidence': analysis['confidence'],
              'is_uploaded': 1,
              'is_dirty': 0,
            },
            where: 'id = ?',
            whereArgs: [analysis['id']],
          );
        }
      }

      // Handle deletions
      for (final id in deletedIds) {
        await txn.delete(
          'disease_analysis_results',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });

    debugPrint(
      '✅ Applied ${analyses.length} updates and ${deletedIds.length} deletions',
    );
  }

  // ================= IMAGE UPLOAD (LOCAL TO SERVER) =================

  /// Sync images: upload local images to server
  Future<Map<String, dynamic>> syncImages(String accessToken) async {
    try {
      final db = await _db.database;

      // Find all images that need uploading
      final pendingImages = await db.query(
        'images',
        where: """
          local_path IS NOT NULL 
          AND local_path != '' 
          AND (
            is_uploaded = 0 
            OR server_image_url IS NULL 
            OR server_image_url = '/uploads/images/pending'
          )
        """,
      );

      debugPrint('📤 Syncing ${pendingImages.length} images...');

      int uploaded = 0;

      for (final image in pendingImages) {
        final localPath = image['local_path'] as String;
        final imageId = image['image_id'] as String;

        if (File(localPath).existsSync()) {
          debugPrint('📤 Uploading image: $imageId from $localPath');
          final result = await _uploadImage(imageId, localPath, accessToken);
          if (result['success']) {
            uploaded++;
            debugPrint('✅ Image uploaded: $imageId');
          } else {
            debugPrint('❌ Failed to upload image $imageId: ${result['error']}');
          }
        } else {
          debugPrint('⚠️ Image file not found: $localPath');
        }
      }

      return {
        'success': true,
        'uploaded': uploaded,
        'total': pendingImages.length,
      };
    } catch (e) {
      debugPrint('❌ Image sync error: $e');
      return {'success': false, 'error': e.toString(), 'uploaded': 0};
    }
  }

  /// Upload single image file to server
  /// Note: Multipart uploads still use raw http since ApiService doesn't support it yet
  Future<Map<String, dynamic>> _uploadImage(
    String imageId,
    String localPath,
    String accessToken,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/sync/images/upload'),
      );

      request.headers['Authorization'] = 'Bearer $accessToken';
      request.fields['image_id'] = imageId;
      request.files.add(await http.MultipartFile.fromPath('image', localPath));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📡 Image upload response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final serverUrl = data['server_image_url'] ?? data['url'];

        // Update local database with server URL
        final db = await _db.database;
        await db.update(
          'images',
          {'server_image_url': serverUrl, 'is_uploaded': 1},
          where: 'image_id = ?',
          whereArgs: [imageId],
        );

        debugPrint(
          '✅ Image uploaded and metadata updated: $imageId -> $serverUrl',
        );
        return {'success': true, 'server_url': serverUrl};
      }

      debugPrint('❌ Image upload failed: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      return {'success': false, 'message': 'HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('❌ Image upload error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= IMAGE DOWNLOAD (SERVER TO LOCAL) =================

  /// Download images from server that don't exist locally
  Future<Map<String, dynamic>> downloadServerImages(String accessToken) async {
    try {
      final db = await _db.database;

      // Find images that have server URLs but no local copy
      final imagesToDownload = await db.query(
        'images',
        where: """
          server_image_url IS NOT NULL 
          AND server_image_url != '' 
          AND server_image_url != '/uploads/images/pending'
          AND (local_path IS NULL OR local_path = '')
        """,
      );

      debugPrint(
        '📥 Downloading ${imagesToDownload.length} images from server...',
      );

      int downloaded = 0;
      final errors = <String>[];

      for (final image in imagesToDownload) {
        final imageId = image['image_id'] as String;
        final serverUrl = image['server_image_url'] as String;

        try {
          final localPath = await _downloadImage(
            imageId,
            serverUrl,
            accessToken,
          );
          if (localPath != null) {
            downloaded++;
            debugPrint('✅ Image downloaded: $imageId -> $localPath');
          }
        } catch (e) {
          debugPrint('❌ Failed to download image $imageId: $e');
          errors.add(imageId);
        }
      }

      return {
        'success': errors.isEmpty,
        'downloaded': downloaded,
        'total': imagesToDownload.length,
        'errors': errors,
      };
    } catch (e) {
      debugPrint('❌ Image download error: $e');
      return {'success': false, 'error': e.toString(), 'downloaded': 0};
    }
  }

  /// Download single image from server and save locally
  /// Note: Binary downloads still use raw http for streaming
  Future<String?> _downloadImage(
    String imageId,
    String serverUrl,
    String accessToken,
  ) async {
    try {
      // Construct full URL
      String fullUrl;
      if (serverUrl.startsWith('http')) {
        fullUrl = serverUrl;
      } else {
        final imageBaseUrl = baseUrl.replaceAll('/api', '');
        fullUrl = '$imageBaseUrl$serverUrl';
      }

      debugPrint('📥 Downloading image from: $fullUrl');

      final response = await http
          .get(
            Uri.parse(fullUrl),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('❌ Download failed: ${response.statusCode}');
        return null;
      }

      // Get app directory for storing images
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/disease_images');

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Generate local filename
      final extension = serverUrl.split('.').last.split('?').first;
      final filename = '$imageId.$extension';
      final localPath = '${imagesDir.path}/$filename';

      // Save image to local file
      final file = File(localPath);
      await file.writeAsBytes(response.bodyBytes);

      debugPrint('💾 Image saved to: $localPath');

      // Update database with local path
      final db = await _db.database;
      await db.update(
        'images',
        {'local_path': localPath},
        where: 'image_id = ?',
        whereArgs: [imageId],
      );

      return localPath;
    } catch (e) {
      debugPrint('❌ Image download error: $e');
      return null;
    }
  }

  // ================= SYNC TIMESTAMP MANAGEMENT =================

  /// Get last sync timestamp from secure storage
  Future<String?> _getLastSyncTimestamp() async {
    try {
      final timestamp = await _storage.read(key: 'disease_analysis_last_sync');
      debugPrint('📅 Last sync timestamp from storage: $timestamp');
      return timestamp;
    } catch (e) {
      debugPrint('⚠️ Error reading last sync timestamp: $e');
      return null;
    }
  }

  /// Update last sync timestamp in secure storage
  Future<void> _updateLastSyncTimestamp(String? timestamp) async {
    if (timestamp == null) return;

    try {
      await _storage.write(key: 'disease_analysis_last_sync', value: timestamp);
      debugPrint('✅ Saved last sync timestamp to storage: $timestamp');
    } catch (e) {
      debugPrint('⚠️ Error saving last sync timestamp: $e');
    }
  }

  // ================= UTILITIES =================

  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    return await _db.getSyncStatus();
  }
}
