import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../../utils/constants.dart';

/// Service for two-way sync of disease analysis and images
class SyncService {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  final DatabaseHelper _db = DatabaseHelper.instance;
  static const String baseUrl = AppConstants.baseUrl;

  // ================= FULL SYNC =================

  /// Perform full sync: catalogs + analyses + images
  Future<Map<String, dynamic>> performFullSync(String accessToken) async {
    try {
      print('🔄 Starting full sync...');

      // Step 1: Sync catalogs (diseases, remedies, plants, etc.)
      final catalogResult = await _db.smartSyncCatalogs(accessToken);

      // Step 2: Two-way sync for analyses and images
      final twoWayResult = await performTwoWaySync(accessToken);

      return {
        'success': catalogResult['success'] && twoWayResult['success'],
        'catalogs': catalogResult,
        'two_way_sync': twoWayResult,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Full sync error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= TWO-WAY SYNC FOR DISEASE ANALYSIS =================

  /// Complete two-way sync: push local changes, then pull server updates
  Future<Map<String, dynamic>> performTwoWaySync(String accessToken) async {
    try {
      print('🔄 Starting two-way sync...');

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
      print('❌ Two-way sync error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= UPLOAD (PUSH LOCAL TO SERVER) =================

  /// Upload pending disease analyses to server as JSON batch
  Future<Map<String, dynamic>> uploadPendingAnalyses(String accessToken) async {
    try {
      final pending = await _db.getPendingAnalyses();
      print('📤 Uploading ${pending.length} pending analyses...');

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

      // Send batch upload as JSON
      final response = await http
          .post(
            Uri.parse('$baseUrl/sync/batch-upload'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'analyses': analysesToUpload}),
          )
          .timeout(const Duration(seconds: 30));

      print('📡 Upload response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final uploadedIds =
            (responseData['uploaded_ids'] as List?)
                ?.map((id) => id.toString())
                .toList() ??
            [];

        // Mark uploaded analyses as synced
        for (final id in uploadedIds) {
          await _db.markAsUploaded(id, null);
        }

        print('✅ Uploaded ${uploadedIds.length} analyses');

        return {
          'success': true,
          'uploaded': uploadedIds.length,
          'uploaded_ids': uploadedIds,
        };
      }

      print('❌ Upload failed: ${response.statusCode}');
      print('Response body: ${response.body}');
      return {
        'success': false,
        'message': 'Upload failed: ${response.statusCode}',
        'uploaded': 0,
      };
    } catch (e) {
      print('❌ Upload error: $e');
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
      // Get last sync timestamp
      final lastSync = since ?? await _getLastSyncTimestamp();

      final uri = lastSync != null
          ? Uri.parse('$baseUrl/sync/changes?since=$lastSync')
          : Uri.parse('$baseUrl/sync/changes');

      print('📥 Downloading analyses since: ${lastSync ?? "beginning"}');

      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(const Duration(seconds: 30));

      print('📡 Download response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final analyses =
            (data['analyses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final deletedIds =
            (data['deleted_ids'] as List?)
                ?.map((id) => id.toString())
                .toList() ??
            [];

        print(
          '📦 Received ${analyses.length} analyses, ${deletedIds.length} deletions',
        );

        // Apply server changes locally
        await _applyServerChanges(analyses, deletedIds);

        // Update sync timestamp
        await _updateLastSyncTimestamp(data['server_timestamp']);

        return {
          'success': true,
          'downloaded': analyses.length,
          'deleted': deletedIds.length,
        };
      }

      print('❌ Download failed: ${response.statusCode}');
      print('Response body: ${response.body}');
      return {
        'success': false,
        'message': 'Download failed: ${response.statusCode}',
        'downloaded': 0,
        'deleted': 0,
      };
    } catch (e) {
      print('❌ Download error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'downloaded': 0,
        'deleted': 0,
      };
    }
  }

  /// Apply server changes to local database
  /// ⭐ Smart handling of placeholder URLs
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

          // ⭐ CHECK: Is this a placeholder URL or real URL?
          final isPlaceholder =
              serverImageUrl == null ||
              serverImageUrl == '/uploads/images/pending' ||
              serverImageUrl.isEmpty;

          if (imageExists.isEmpty) {
            // Insert new image record
            await txn.insert('images', {
              'image_id': analysis['image_id'],
              'local_path': '', // Empty for server-only images
              'server_image_url': serverImageUrl,
              'is_uploaded': isPlaceholder
                  ? 0
                  : 1, // ⭐ Only mark as uploaded if real URL
            });
            print(
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
                'is_uploaded': isPlaceholder
                    ? 0
                    : 1, // ⭐ Only mark as uploaded if real URL
                // ⭐ PRESERVE: Keep local_path if it exists
                if (existingLocalPath != null && existingLocalPath.isNotEmpty)
                  'local_path': existingLocalPath,
              },
              where: 'image_id = ?',
              whereArgs: [analysis['image_id']],
            );
            print(
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

    print(
      '✅ Applied ${analyses.length} updates and ${deletedIds.length} deletions',
    );
  }

  // ================= IMAGE UPLOAD (LOCAL TO SERVER) =================

  /// Sync images: upload local images to server
  /// ⭐ Comprehensive query to catch all pending images
  Future<Map<String, dynamic>> syncImages(String accessToken) async {
    try {
      final db = await _db.database;

      // ⭐ COMPREHENSIVE QUERY: Find all images that need uploading
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

      print('🖼️ Syncing ${pendingImages.length} images...');

      int uploaded = 0;

      for (final image in pendingImages) {
        final localPath = image['local_path'] as String;
        final imageId = image['image_id'] as String;

        if (File(localPath).existsSync()) {
          print('📤 Uploading image: $imageId from $localPath');
          final result = await _uploadImage(imageId, localPath, accessToken);
          if (result['success']) {
            uploaded++;
            print('✅ Image uploaded: $imageId');
          } else {
            print('❌ Failed to upload image $imageId: ${result['error']}');
          }
        } else {
          print('⚠️ Image file not found: $localPath');
        }
      }

      return {
        'success': true,
        'uploaded': uploaded,
        'total': pendingImages.length,
      };
    } catch (e) {
      print('❌ Image sync error: $e');
      return {'success': false, 'error': e.toString(), 'uploaded': 0};
    }
  }

  /// Upload single image file to server
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

      print('📡 Image upload response: ${response.statusCode}');

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

        print('✅ Image uploaded and metadata updated: $imageId -> $serverUrl');
        return {'success': true, 'server_url': serverUrl};
      }

      print('❌ Image upload failed: ${response.statusCode}');
      print('Response body: ${response.body}');
      return {'success': false, 'message': 'HTTP ${response.statusCode}'};
    } catch (e) {
      print('❌ Image upload error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ================= IMAGE DOWNLOAD (SERVER TO LOCAL) =================

  /// Download images from server that don't exist locally
  /// ⭐ Download server images to local storage
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

      print('📥 Downloading ${imagesToDownload.length} images from server...');

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
            print('✅ Image downloaded: $imageId -> $localPath');
          }
        } catch (e) {
          print('❌ Failed to download image $imageId: $e');
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
      print('❌ Image download error: $e');
      return {'success': false, 'error': e.toString(), 'downloaded': 0};
    }
  }

  /// Download single image from server and save locally
  /// ⭐ FIX: Removes /api from baseUrl for image downloads
  Future<String?> _downloadImage(
    String imageId,
    String serverUrl,
    String accessToken,
  ) async {
    try {
      // Construct full URL
      String fullUrl;
      if (serverUrl.startsWith('http')) {
        // Already a full URL
        fullUrl = serverUrl;
      } else {
        // ⭐ FIX: Remove '/api' from baseUrl for image downloads
        // baseUrl = http://10.21.79.141:5000/api
        // imageBaseUrl = http://10.21.79.141:5000
        final imageBaseUrl = baseUrl.replaceAll('/api', '');
        fullUrl = '$imageBaseUrl$serverUrl';
      }

      print('📥 Downloading image from: $fullUrl');

      // Download image
      final response = await http
          .get(
            Uri.parse(fullUrl),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        print('❌ Download failed: ${response.statusCode}');
        return null;
      }

      // Get app directory for storing images
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/disease_images');

      // Create directory if it doesn't exist
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

      print('💾 Image saved to: $localPath');

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
      print('❌ Image download error: $e');
      return null;
    }
  }

  // ================= SYNC TIMESTAMP MANAGEMENT =================

  Future<String?> _getLastSyncTimestamp() async {
    final db = await _db.database;
    final result = await db.query(
      'reference_table_versions',
      where: 'ref_table_name = ?',
      whereArgs: ['disease_analysis_sync'],
      limit: 1,
    );

    return result.isNotEmpty ? result.first['updated_at'] as String : null;
  }

  Future<void> _updateLastSyncTimestamp(String? timestamp) async {
    if (timestamp == null) return;

    final db = await _db.database;
    await db.insert('reference_table_versions', {
      'ref_table_name': 'disease_analysis_sync',
      'updated_at': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ================= UTILITIES =================

  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    return await _db.getSyncStatus();
  }
}
