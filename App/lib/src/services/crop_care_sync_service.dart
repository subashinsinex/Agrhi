import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/database_helper.dart';
import 'api_service.dart';

/// Service for two-way sync of farms, crops, and crop history
class CropCareSyncService {
  static final CropCareSyncService instance = CropCareSyncService._init();
  CropCareSyncService._init();

  final DatabaseHelper _db = DatabaseHelper.instance;

  // ✅ Sync lock to prevent duplicate syncs
  bool _isSyncing = false;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  // ==================== HELPER ====================

  int _toBoolInt(dynamic value) {
    if (value == null) return 0;
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value == 0 ? 0 : 1;
    if (value is String) {
      final lower = value.toLowerCase();
      return (lower == 'true' || lower == '1') ? 1 : 0;
    }
    return 0;
  }

  // ==================== FULL SYNC ====================

  Future<Map<String, dynamic>> performFullSync(String accessToken) async {
    // ✅ Check if already syncing
    if (_isSyncing) {
      debugPrint('⏭️ CropCare sync already in progress - skipping');
      return {
        'success': false,
        'error': 'Sync already in progress',
        'skipped': true,
      };
    }

    _isSyncing = true; // ✅ Lock sync

    try {
      debugPrint('🔄 Starting CropCare full sync...');

      final syncResult = await performTwoWaySync(accessToken);

      final success = syncResult['success'];

      if (success) {
        debugPrint('✅ Crop care sync completed');
      }

      return {
        'success': success,
        'sync': syncResult,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ CropCare sync error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } finally {
      _isSyncing = false; // ✅ Unlock sync
    }
  }

  // ==================== TWO-WAY SYNC ====================

  Future<Map<String, dynamic>> performTwoWaySync(String accessToken) async {
    try {
      debugPrint('🔄 Starting CropCare two-way sync...');

      // ✅ Upload deletions FIRST, then other changes, then download
      final farmDeletionResult = await uploadPendingFarmDeletions(accessToken);
      final cropDeletionResult = await uploadPendingCropDeletions(accessToken);
      final farmUploadResult = await uploadPendingFarms(accessToken);
      final cropUploadResult = await uploadPendingCrops(accessToken);

      // ✅ Upload inactive crop changes (reactivations)
      final reactivationResult = await uploadInactiveCropChanges(accessToken);

      final farmDownloadResult = await downloadServerFarms(accessToken);
      final cropDownloadResult = await downloadServerCrops(accessToken);

      // ✅ Download crop history separately
      final historyDownloadResult = await downloadCropHistory(accessToken);

      final allSuccess =
          farmDeletionResult['success'] &&
          cropDeletionResult['success'] &&
          farmUploadResult['success'] &&
          cropUploadResult['success'] &&
          reactivationResult['success'] &&
          farmDownloadResult['success'] &&
          cropDownloadResult['success'] &&
          historyDownloadResult['success'];

      return {
        'success': allSuccess,
        'farmDeletion': farmDeletionResult,
        'cropDeletion': cropDeletionResult,
        'farmUpload': farmUploadResult,
        'cropUpload': cropUploadResult,
        'reactivation': reactivationResult,
        'farmDownload': farmDownloadResult,
        'cropDownload': cropDownloadResult,
        'historyDownload': historyDownloadResult,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Two-way sync error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // ==================== SOFT DELETE SYNC ====================

  /// Upload pending farm deletions to server
  Future<Map<String, dynamic>> uploadPendingFarmDeletions(
    String accessToken,
  ) async {
    try {
      final pendingDeletions = await _db.getPendingFarmDeletions();
      debugPrint('🗑️ Uploading ${pendingDeletions.length} farm deletions...');

      if (pendingDeletions.isEmpty) {
        return {
          'success': true,
          'message': 'No pending farm deletions',
          'synced': 0,
        };
      }

      int synced = 0;
      int failed = 0;
      final List<String> failedIds = [];

      for (final farm in pendingDeletions) {
        final farmId = farm['farmid'] as String;

        try {
          // ✅ USE ApiService
          final response = await ApiService.instance.put(
            '/farmcrop/isdeletefarms/$farmId',
            requiresAuth: true,
          );

          debugPrint('📡 Farm deletion response: ${response.statusCode}');

          if (response.isSuccess || response.statusCode == 404) {
            await _db.cleanupDeletedFarm(farmId);
            synced++;
            debugPrint('✅ Farm deletion synced and cleaned up: $farmId');
          } else {
            failed++;
            failedIds.add(farmId);
            debugPrint(
              '❌ Failed to sync farm deletion: $farmId (${response.error})',
            );
          }
        } catch (e) {
          failed++;
          failedIds.add(farmId);
          debugPrint('❌ Error syncing farm deletion $farmId: $e');
        }
      }

      return {
        'success': failed == 0,
        'synced': synced,
        'failed': failed,
        'failedIds': failedIds,
        'message': failed == 0
            ? 'All farm deletions synced and cleaned up'
            : 'Synced $synced/${pendingDeletions.length} farm deletions',
      };
    } catch (e) {
      debugPrint('❌ Farm deletion sync error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Upload pending crop deletions to server
  Future<Map<String, dynamic>> uploadPendingCropDeletions(
    String accessToken,
  ) async {
    try {
      final pendingDeletions = await _db.getPendingCropDeletions();
      debugPrint('🗑️ Uploading ${pendingDeletions.length} crop deletions...');

      if (pendingDeletions.isEmpty) {
        return {
          'success': true,
          'message': 'No pending crop deletions',
          'synced': 0,
        };
      }

      int synced = 0;
      int failed = 0;
      final List<String> failedIds = [];

      for (final crop in pendingDeletions) {
        final cropId = crop['usercropid'] as String;

        try {
          // ✅ USE ApiService
          final response = await ApiService.instance.put(
            '/farmcrop/isdeletecrops/$cropId',
            requiresAuth: true,
          );

          debugPrint('📡 Crop deletion response: ${response.statusCode}');

          if (response.isSuccess || response.statusCode == 404) {
            await _db.cleanupDeletedCrop(cropId);
            synced++;
            debugPrint('✅ Crop deletion synced and cleaned up: $cropId');
          } else {
            failed++;
            failedIds.add(cropId);
            debugPrint(
              '❌ Failed to sync crop deletion: $cropId (${response.error})',
            );
          }
        } catch (e) {
          failed++;
          failedIds.add(cropId);
          debugPrint('❌ Error syncing crop deletion $cropId: $e');
        }
      }

      return {
        'success': failed == 0,
        'synced': synced,
        'failed': failed,
        'failedIds': failedIds,
        'message': failed == 0
            ? 'All crop deletions synced and cleaned up'
            : 'Synced $synced/${pendingDeletions.length} crop deletions',
      };
    } catch (e) {
      debugPrint('❌ Crop deletion sync error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ==================== UPLOAD ====================

  Future<Map<String, dynamic>> uploadPendingFarms(String accessToken) async {
    try {
      final pending = await _db.getPendingFarms();
      debugPrint('📤 Uploading ${pending.length} pending farms...');

      if (pending.isEmpty) {
        return {'success': true, 'message': 'No pending farms', 'uploaded': 0};
      }

      final userId = await _storage.read(key: 'user_id');
      if (userId == null) {
        debugPrint('❌ User ID not found');
        return {
          'success': false,
          'message': 'User ID not found',
          'uploaded': 0,
        };
      }

      int uploadedCount = 0;
      final uploadedIds = <String>[];

      for (final farm in pending) {
        try {
          final farmId = farm['farmid'] as String;
          final farmWithRelations = await _db.getFarmWithRelations(farmId);

          if (farmWithRelations == null) continue;

          final wasUploaded = farm['isuploaded'] == 1;

          Map<String, dynamic> payload;
          ApiResponse response;

          if (wasUploaded) {
            // ✅ UPDATE existing farm
            payload = {
              'farm_size': farmWithRelations['farmsize'],
              'survey_number': farmWithRelations['surveynumber'],
              'soil_type_ids': farmWithRelations['soil_type_ids'] ?? [],
              'irrigation_ids': farmWithRelations['irrigation_ids'] ?? [],
              'water_src_ids': farmWithRelations['water_source_ids'] ?? [],
            };
            debugPrint('📝 Updating farm $farmId');

            response = await ApiService.instance.put(
              '/farmcrop/updatefarms/$farmId',
              body: payload,
              requiresAuth: true,
            );
          } else {
            // ✅ ADD new farm
            payload = {
              'user_id': userId,
              'farm_id': farmId,
              'farm_size': farmWithRelations['farmsize'],
              'survey_number': farmWithRelations['surveynumber'],
              'soil_type_ids': farmWithRelations['soil_type_ids'] ?? [],
              'irrigation_ids': farmWithRelations['irrigation_ids'] ?? [],
              'water_src_ids': farmWithRelations['water_source_ids'] ?? [],
            };
            debugPrint('➕ Adding new farm $farmId');

            response = await ApiService.instance.post(
              '/farmcrop/addfarmsbyid',
              body: payload,
              requiresAuth: true,
            );
          }

          debugPrint(
            '📡 Farm ${wasUploaded ? "update" : "add"} response: ${response.statusCode}',
          );

          if (response.isSuccess) {
            await _db.markFarmAsUploaded(farmId);
            uploadedCount++;
            uploadedIds.add(farmId);
            debugPrint('✅ Farm ${wasUploaded ? "updated" : "added"}: $farmId');
          } else if (response.statusCode == 500 || response.statusCode == 409) {
            try {
              final errorData = response.data;
              if (errorData is Map) {
                final errorCode = errorData['error']?['code'];
                final errorDetail =
                    errorData['error']?['detail']?.toString() ?? '';

                if (errorCode == '23505' ||
                    errorDetail.contains('already exists')) {
                  debugPrint(
                    'ℹ️ Farm already exists, marking as uploaded: $farmId',
                  );
                  await _db.markFarmAsUploaded(farmId);
                  uploadedCount++;
                  uploadedIds.add(farmId);
                } else {
                  debugPrint('❌ Upload failed for $farmId: ${response.error}');
                }
              }
            } catch (e) {
              debugPrint('❌ Upload failed for $farmId: ${response.error}');
            }
          } else {
            debugPrint('❌ Upload failed for $farmId: ${response.error}');
          }
        } catch (e) {
          debugPrint('❌ Error uploading farm: $e');
        }
      }

      return {
        'success': uploadedCount == pending.length,
        'uploaded': uploadedCount,
        'uploaded_ids': uploadedIds,
        'message': uploadedCount == pending.length
            ? 'All farms uploaded'
            : 'Uploaded $uploadedCount/${pending.length} farms',
      };
    } catch (e) {
      debugPrint('❌ Farm upload error: $e');
      return {'success': false, 'error': e.toString(), 'uploaded': 0};
    }
  }

  Future<Map<String, dynamic>> uploadPendingCrops(String accessToken) async {
    try {
      final pending = await _db.getPendingCrops();
      debugPrint('📤 Uploading ${pending.length} pending crops...');

      if (pending.isEmpty) {
        return {'success': true, 'message': 'No pending crops', 'uploaded': 0};
      }

      int uploadedCount = 0;
      final uploadedIds = <String>[];

      for (final crop in pending) {
        try {
          final cropId = crop['usercropid'] as String;
          final wasUploaded = crop['isuploaded'] == 1;

          Map<String, dynamic> payload;
          ApiResponse response;

          if (wasUploaded) {
            // ✅ UPDATE existing crop
            debugPrint('📝 Updating crop $cropId');
            payload = {
              'farm_id': crop['farmid'],
              'plant_id': crop['plantid'],
              'planting_date': crop['plantingdate'],
              'harvest_date': crop['harvestdate'],
              'field_size': crop['fieldsize'],
              'status': crop['status'],
              'is_active': crop['isactive'] == 1,
              'is_delete': crop['isdeleted'] == 1,
            };

            response = await ApiService.instance.put(
              '/farmcrop/updatecrops/$cropId',
              body: payload,
              requiresAuth: true,
            );
          } else {
            // ✅ ADD new crop
            debugPrint('➕ Adding crop $cropId');
            payload = {
              'user_crop_id': cropId,
              'farm_id': crop['farmid'],
              'plant_id': crop['plantid'],
              'planting_date': crop['plantingdate'],
              'harvest_date': crop['harvestdate'],
              'field_size': crop['fieldsize'],
              'status': crop['status'],
              'is_active': crop['isactive'] == 1,
              'is_delete': crop['isdeleted'] == 1,
            };

            response = await ApiService.instance.post(
              '/farmcrop/addcrops',
              body: payload,
              requiresAuth: true,
            );
          }

          debugPrint(
            '📡 Crop ${wasUploaded ? "update" : "add"} response: ${response.statusCode}',
          );

          if (response.isSuccess) {
            await _db.markCropAsUploaded(cropId);
            uploadedCount++;
            uploadedIds.add(cropId);
            debugPrint('✅ Crop ${wasUploaded ? "updated" : "added"}: $cropId');
          } else if (response.statusCode == 500 || response.statusCode == 409) {
            try {
              final errorData = response.data;
              if (errorData is Map) {
                final errorCode = errorData['error']?['code'];
                final errorDetail =
                    errorData['error']?['detail']?.toString() ?? '';

                if (errorCode == '23505' ||
                    errorDetail.contains('already exists')) {
                  debugPrint(
                    'ℹ️ Crop already exists, marking as uploaded: $cropId',
                  );
                  await _db.markCropAsUploaded(cropId);
                  uploadedCount++;
                  uploadedIds.add(cropId);
                } else {
                  debugPrint('❌ Upload failed for $cropId: ${response.error}');
                }
              }
            } catch (e) {
              debugPrint('❌ Upload failed for $cropId: ${response.error}');
            }
          } else {
            debugPrint('❌ Upload failed for $cropId: ${response.error}');
          }
        } catch (e) {
          debugPrint('❌ Error uploading crop: $e');
        }
      }

      return {
        'success': uploadedCount == pending.length,
        'uploaded': uploadedCount,
        'uploaded_ids': uploadedIds,
        'message': uploadedCount == pending.length
            ? 'All crops uploaded'
            : 'Uploaded $uploadedCount/${pending.length} crops',
      };
    } catch (e) {
      debugPrint('❌ Crop upload error: $e');
      return {'success': false, 'error': e.toString(), 'uploaded': 0};
    }
  }

  // ==================== CROP HISTORY SYNC ====================

  /// Upload inactive crop status changes (reactivations)
  Future<Map<String, dynamic>> uploadInactiveCropChanges(
    String accessToken,
  ) async {
    try {
      final pendingCrops = await _db.getPendingCrops();
      final reactivated = pendingCrops
          .where((c) => c['isactive'] == 1 && c['isdirty'] == 1)
          .toList();

      debugPrint('📤 Uploading ${reactivated.length} reactivated crops...');

      if (reactivated.isEmpty) {
        return {
          'success': true,
          'message': 'No reactivated crops',
          'uploaded': 0,
        };
      }

      int uploaded = 0;
      final List<String> failedIds = [];

      for (final crop in reactivated) {
        try {
          final cropId = crop['usercropid'] as String;

          // ✅ USE ApiService
          final response = await ApiService.instance.put(
            '/farmcrop/updatecrops/$cropId',
            body: {
              'farm_id': crop['farmid'],
              'plant_id': crop['plantid'],
              'planting_date': crop['plantingdate'],
              'harvest_date': crop['harvestdate'],
              'field_size': crop['fieldsize'],
              'status': crop['status'],
              'is_active': true,
              'is_delete': crop['isdeleted'] == 1,
            },
            requiresAuth: true,
          );

          debugPrint(
            '📡 Reactivation response for $cropId: ${response.statusCode}',
          );

          if (response.isSuccess) {
            await _db.markCropAsUploaded(cropId);
            uploaded++;
            debugPrint('✅ Reactivated crop synced: $cropId');
          } else {
            failedIds.add(cropId);
            debugPrint('❌ Failed to sync reactivation for $cropId');
          }
        } catch (e) {
          failedIds.add(crop['usercropid'] as String);
          debugPrint('❌ Error syncing reactivated crop: $e');
        }
      }

      return {
        'success': uploaded == reactivated.length,
        'uploaded': uploaded,
        'failed': failedIds.length,
        'failedIds': failedIds,
        'message': uploaded == reactivated.length
            ? 'All reactivations uploaded'
            : 'Uploaded $uploaded/${reactivated.length} reactivations',
      };
    } catch (e) {
      debugPrint('❌ Reactivation sync error: $e');
      return {'success': false, 'error': e.toString(), 'uploaded': 0};
    }
  }

  /// Download crop history (inactive crops) from server per farm
  Future<Map<String, dynamic>> downloadCropHistory(String accessToken) async {
    try {
      final farms = await _db.getAllFarms();

      if (farms.isEmpty) {
        debugPrint('ℹ️ No farms to download crop history for');
        return {'success': true, 'downloaded': 0};
      }

      int totalHistoryCrops = 0;
      final List<Map<String, dynamic>> allHistoryCrops = [];

      for (final farm in farms) {
        final farmId = farm['farmid'] as String;

        try {
          debugPrint('📥 Downloading crop history for farm $farmId');

          // ✅ USE ApiService
          final response = await ApiService.instance.get(
            '/farmcrop/crophistory/$farmId',
            requiresAuth: true,
          );

          debugPrint(
            '📡 Crop history response for farm $farmId: ${response.statusCode}',
          );

          if (response.isSuccess) {
            final data = response.data;

            List<dynamic> historyList;
            if (data is List) {
              historyList = data;
            } else if (data is Map && data['crops'] is List) {
              historyList = data['crops'];
            } else if (data is Map && data['data'] is List) {
              historyList = data['data'];
            } else {
              historyList = [];
            }

            for (var crop in historyList) {
              if (crop is Map<String, dynamic>) {
                crop['farm_id'] = farmId;
                allHistoryCrops.add(crop);
              }
            }

            totalHistoryCrops += historyList.length;
          } else if (response.statusCode == 404) {
            debugPrint('ℹ️ No crop history found for farm $farmId');
          }
        } catch (e) {
          debugPrint('⚠️ Error downloading crop history for farm $farmId: $e');
        }
      }

      debugPrint('📦 Received $totalHistoryCrops history crops from server');

      if (allHistoryCrops.isNotEmpty) {
        await _applyServerCropHistory(allHistoryCrops);
      }

      await _updateLastHistorySyncTimestamp(DateTime.now().toIso8601String());

      return {'success': true, 'downloaded': totalHistoryCrops};
    } catch (e) {
      debugPrint('❌ Crop history download error: $e');
      return {'success': false, 'error': e.toString(), 'downloaded': 0};
    }
  }

  /// Apply server crop history to local database
  Future<void> _applyServerCropHistory(List<Map<String, dynamic>> crops) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      for (final crop in crops) {
        try {
          final isActive = _toBoolInt(crop['is_active'] ?? crop['isactive']);

          if (isActive == 1) {
            debugPrint(
              '⚠️ Skipping active crop in history: ${crop['user_crop_id']}',
            );
            continue;
          }

          String? cropId = crop['user_crop_id'] ?? crop['usercropid'];
          final farmIdFromServer = crop['farm_id'] ?? crop['farmid'];

          if (cropId == null || farmIdFromServer == null) {
            debugPrint('⚠️ Skipping incomplete history crop data');
            continue;
          }

          final farmId = farmIdFromServer.toString();
          String? plantId = crop['plant_id'] ?? crop['plantid'];

          if (plantId == null && crop['plant_name'] != null) {
            final result = await txn.query(
              'plants',
              columns: ['plantid'],
              where: 'LOWER(plantname) = LOWER(?)',
              whereArgs: [crop['plant_name']],
              limit: 1,
            );
            if (result.isNotEmpty) {
              plantId = result.first['plantid'].toString();
            }
          }

          if (plantId == null) {
            debugPrint('⚠️ Skipping history crop without plant_id');
            continue;
          }

          String? soilTypeId = crop['soil_type_id'] ?? crop['soiltypeid'];

          if (soilTypeId == null) {
            final farmSoilTypes = await txn.query(
              'farm_soiltypes',
              columns: ['soil_type_id'],
              where: 'farm_id = ?',
              whereArgs: [farmId],
              limit: 1,
            );

            if (farmSoilTypes.isNotEmpty) {
              soilTypeId = farmSoilTypes.first['soil_type_id'].toString();
            } else {
              final anySoilType = await txn.query(
                'soiltypes',
                columns: ['soiltypeid'],
                limit: 1,
              );
              if (anySoilType.isNotEmpty) {
                soilTypeId = anySoilType.first['soiltypeid'].toString();
              } else {
                debugPrint('❌ No soil type available for history crop');
                continue;
              }
            }
          }

          final exists = await txn.query(
            'usercrops',
            where: 'usercropid = ?',
            whereArgs: [cropId],
            limit: 1,
          );

          final row = {
            'usercropid': cropId,
            'farmid': farmId,
            'plantid': plantId.toString(),
            'plantingdate': crop['planting_date'] ?? crop['plantingdate'],
            'harvestdate': crop['harvest_date'] ?? crop['harvestdate'],
            'fieldsize': crop['field_size'] ?? crop['fieldsize'],
            'soiltypeid': soilTypeId,
            'status': crop['status'] ?? 'Completed',
            'isactive': 0,
            'createdat':
                crop['created_at'] ??
                crop['createdat'] ??
                DateTime.now().toIso8601String(),
            'isuploaded': 1,
            'isdirty': 0,
            'isdeleted': 0,
          };

          if (exists.isEmpty) {
            await txn.insert('usercrops', row);
            debugPrint('➕ Added history crop: $cropId (${crop['plant_name']})');
          } else {
            final localCrop = exists.first;
            if (localCrop['isdirty'] == 0) {
              await txn.update(
                'usercrops',
                row,
                where: 'usercropid = ?',
                whereArgs: [cropId],
              );
              debugPrint(
                '📝 Updated history crop: $cropId (${crop['plant_name']})',
              );
            } else {
              debugPrint('⏭️ Skipping locally modified history crop: $cropId');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error processing history crop: $e');
          continue;
        }
      }
    });

    debugPrint('✅ Applied ${crops.length} history crops from server');
  }

  // ==================== DOWNLOAD ====================

  Future<Map<String, dynamic>> downloadServerFarms(String accessToken) async {
    try {
      final userId = await _storage.read(key: 'user_id');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      debugPrint('📥 Downloading all farms for user $userId');

      // ✅ USE ApiService
      final response = await ApiService.instance.get(
        '/farmcrop/farms/$userId',
        requiresAuth: true,
      );

      debugPrint('📡 Farm download response: ${response.statusCode}');

      if (response.isSuccess) {
        final data = response.data;

        List<dynamic> farmsList;
        if (data is List) {
          farmsList = data;
        } else if (data is Map && data['farms'] is List) {
          farmsList = data['farms'];
        } else if (data is Map && data['data'] is List) {
          farmsList = data['data'];
        } else {
          farmsList = [];
        }

        final farms = farmsList.cast<Map<String, dynamic>>();

        debugPrint('📦 Received ${farms.length} farms from server');

        await _applyServerFarms(farms);

        return {'success': true, 'downloaded': farms.length, 'deleted': 0};
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No farms found on server');
        return {'success': true, 'downloaded': 0, 'deleted': 0};
      }

      return {
        'success': false,
        'message': 'Download failed: ${response.error}',
        'downloaded': 0,
        'deleted': 0,
      };
    } catch (e) {
      debugPrint('❌ Farm download error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'downloaded': 0,
        'deleted': 0,
      };
    }
  }

  Future<Map<String, dynamic>> downloadServerCrops(String accessToken) async {
    try {
      final userId = await _storage.read(key: 'user_id');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      final farms = await _db.getAllFarms();

      if (farms.isEmpty) {
        debugPrint('ℹ️ No farms to download crops for');
        return {'success': true, 'downloaded': 0, 'deleted': 0};
      }

      int totalCrops = 0;
      final List<Map<String, dynamic>> allCrops = [];

      for (final farm in farms) {
        final farmId = farm['farmid'] as String;

        try {
          debugPrint('📥 Downloading crops for farm $farmId');

          // ✅ USE ApiService
          final response = await ApiService.instance.get(
            '/farmcrop/crops/$farmId',
            requiresAuth: true,
          );

          if (response.isSuccess) {
            final data = response.data;

            List<dynamic> cropsList;
            if (data is List) {
              cropsList = data;
            } else if (data is Map && data['crops'] is List) {
              cropsList = data['crops'];
            } else if (data is Map && data['data'] is List) {
              cropsList = data['data'];
            } else {
              cropsList = [];
            }

            for (var crop in cropsList) {
              if (crop is Map<String, dynamic>) {
                crop['farm_id'] = farmId;
                allCrops.add(crop);
              }
            }

            totalCrops += cropsList.length;
          }
        } catch (e) {
          debugPrint('⚠️ Error downloading crops for farm $farmId: $e');
        }
      }

      debugPrint('📦 Received $totalCrops crops from server');

      await _applyServerCrops(allCrops);

      return {'success': true, 'downloaded': totalCrops, 'deleted': 0};
    } catch (e) {
      debugPrint('❌ Crop download error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'downloaded': 0,
        'deleted': 0,
      };
    }
  }

  // ==================== APPLY SERVER CHANGES ====================

  Future<void> _applyServerFarms(List<Map<String, dynamic>> farms) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      for (final farm in farms) {
        try {
          final farmIdFromServer = (farm['farm_id'] ?? farm['farmid'])
              .toString();
          final farmSize = farm['farm_size'] ?? farm['farmsize'];
          final surveyNumber = farm['survey_number'] ?? farm['surveynumber'];
          final createdAt =
              farm['created_at'] ??
              farm['createdat'] ??
              DateTime.now().toIso8601String();

          final existingFarm = await txn.query(
            'farms',
            where: 'surveynumber = ?',
            whereArgs: [surveyNumber],
            limit: 1,
          );

          String farmId;
          if (existingFarm.isEmpty) {
            farmId = farmIdFromServer;
            await txn.insert('farms', {
              'farmid': farmId,
              'farmsize': farmSize,
              'surveynumber': surveyNumber,
              'createdat': createdAt,
              'isuploaded': 1,
              'isdirty': 0,
              'isdeleted': 0,
            });
            debugPrint('➕ Added farm from server: $farmId');
          } else {
            farmId = existingFarm.first['farmid'].toString();
            await txn.update(
              'farms',
              {
                'farmsize': farmSize,
                'surveynumber': surveyNumber,
                'createdat': createdAt,
                'isuploaded': 1,
                'isdirty': 0,
                'isdeleted': 0,
              },
              where: 'surveynumber = ?',
              whereArgs: [surveyNumber],
            );
            debugPrint(
              '📝 Updated farm (kept farmid=$farmId) for surveynumber $surveyNumber',
            );
          }

          // Handle relations
          List<String> soilTypeIds = [];
          List<String> irrigationIds = [];
          List<String> waterSourceIds = [];

          if (farm['soil_type_ids'] != null) {
            soilTypeIds =
                (farm['soil_type_ids'] as List?)
                    ?.map((id) => id.toString())
                    .toList() ??
                [];
          } else if (farm['soil_types'] != null) {
            final types =
                (farm['soil_types'] as List?)
                    ?.map((n) => n.toString())
                    .toList() ??
                [];
            for (final name in types) {
              final result = await txn.query(
                'soiltypes',
                columns: ['soiltypeid'],
                where: 'LOWER(name) = LOWER(?)',
                whereArgs: [name],
                limit: 1,
              );
              if (result.isNotEmpty) {
                soilTypeIds.add(result.first['soiltypeid'].toString());
              }
            }
          }

          if (farm['irrigation_ids'] != null) {
            irrigationIds =
                (farm['irrigation_ids'] as List?)
                    ?.map((id) => id.toString())
                    .toList() ??
                [];
          } else if (farm['irrigation_methods'] != null) {
            final types =
                (farm['irrigation_methods'] as List?)
                    ?.map((n) => n.toString())
                    .toList() ??
                [];
            for (final name in types) {
              final result = await txn.query(
                'irrigationmethod',
                columns: ['irrigationid'],
                where: 'LOWER(methodname) = LOWER(?)',
                whereArgs: [name],
                limit: 1,
              );
              if (result.isNotEmpty) {
                irrigationIds.add(result.first['irrigationid'].toString());
              }
            }
          }

          if (farm['water_src_ids'] != null ||
              farm['water_source_ids'] != null) {
            waterSourceIds =
                ((farm['water_src_ids'] ?? farm['water_source_ids']) as List?)
                    ?.map((id) => id.toString())
                    .toList() ??
                [];
          } else if (farm['water_sources'] != null) {
            final types =
                (farm['water_sources'] as List?)
                    ?.map((n) => n.toString())
                    .toList() ??
                [];
            for (final name in types) {
              final result = await txn.query(
                'watersrc',
                columns: ['watersrcid'],
                where: 'LOWER(source) = LOWER(?)',
                whereArgs: [name],
                limit: 1,
              );
              if (result.isNotEmpty) {
                waterSourceIds.add(result.first['watersrcid'].toString());
              }
            }
          }

          // Clear existing relations
          await txn.delete(
            'farm_soiltypes',
            where: 'farm_id = ?',
            whereArgs: [farmId],
          );
          await txn.delete(
            'farm_irrigations',
            where: 'farm_id = ?',
            whereArgs: [farmId],
          );
          await txn.delete(
            'farm_watersources',
            where: 'farm_id = ?',
            whereArgs: [farmId],
          );

          // Insert new relations
          for (final soilTypeId in soilTypeIds) {
            await txn.insert('farm_soiltypes', {
              'farm_id': farmId,
              'soil_type_id': soilTypeId,
            });
          }

          for (final irrigationId in irrigationIds) {
            await txn.insert('farm_irrigations', {
              'farm_id': farmId,
              'irrigation_id': irrigationId,
            });
          }

          for (final waterSourceId in waterSourceIds) {
            await txn.insert('farm_watersources', {
              'farm_id': farmId,
              'water_src_id': waterSourceId,
            });
          }
        } catch (e) {
          debugPrint('⚠️ Error applying farm: $e');
          continue;
        }
      }
    });

    debugPrint(
      '✅ Applied ${farms.length} farms from server with junction tables',
    );
  }

  Future<void> _applyServerCrops(List<Map<String, dynamic>> crops) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      for (final crop in crops) {
        try {
          String? cropId = crop['user_crop_id'] ?? crop['usercropid'];
          final farmIdFromServer = crop['farm_id'] ?? crop['farmid'];

          if (cropId == null || farmIdFromServer == null) {
            debugPrint('⚠️ Skipping incomplete crop data');
            continue;
          }

          final farmId = farmIdFromServer.toString();
          String? plantId = crop['plant_id'] ?? crop['plantid'];

          if (plantId == null && crop['plant_name'] != null) {
            final result = await txn.query(
              'plants',
              columns: ['plantid'],
              where: 'LOWER(plantname) = LOWER(?)',
              whereArgs: [crop['plant_name']],
              limit: 1,
            );
            if (result.isNotEmpty) {
              plantId = result.first['plantid'].toString();
            }
          }

          if (plantId == null) {
            debugPrint('⚠️ Skipping crop without plant_id');
            continue;
          }

          String? soilTypeId = crop['soil_type_id'] ?? crop['soiltypeid'];

          if (soilTypeId == null) {
            final farmSoilTypes = await txn.query(
              'farm_soiltypes',
              columns: ['soil_type_id'],
              where: 'farm_id = ?',
              whereArgs: [farmId],
              limit: 1,
            );

            if (farmSoilTypes.isNotEmpty) {
              soilTypeId = farmSoilTypes.first['soil_type_id'].toString();
            } else {
              final anySoilType = await txn.query(
                'soiltypes',
                columns: ['soiltypeid'],
                limit: 1,
              );
              if (anySoilType.isNotEmpty) {
                soilTypeId = anySoilType.first['soiltypeid'].toString();
              } else {
                debugPrint('❌ No soil type available');
                continue;
              }
            }
          }

          final isActive = _toBoolInt(crop['is_active'] ?? crop['isactive']);
          final isDeleted = _toBoolInt(crop['is_delete'] ?? crop['isdeleted']);

          final exists = await txn.query(
            'usercrops',
            where: 'usercropid = ?',
            whereArgs: [cropId],
            limit: 1,
          );

          final row = {
            'usercropid': cropId,
            'farmid': farmId,
            'plantid': plantId.toString(),
            'plantingdate': crop['planting_date'] ?? crop['plantingdate'],
            'harvestdate': crop['harvest_date'] ?? crop['harvestdate'],
            'fieldsize': crop['field_size'] ?? crop['fieldsize'],
            'soiltypeid': soilTypeId,
            'status': crop['status'] ?? 'Active',
            'isactive': isActive,
            'createdat':
                crop['created_at'] ??
                crop['createdat'] ??
                DateTime.now().toIso8601String(),
            'isuploaded': 1,
            'isdirty': 0,
            'isdeleted': isDeleted,
          };

          if (exists.isEmpty) {
            await txn.insert('usercrops', row);
            debugPrint(
              '➕ Added crop from server: $cropId (${crop['plant_name']})',
            );
          } else {
            final localCrop = exists.first;
            if (localCrop['isdirty'] == 0) {
              await txn.update(
                'usercrops',
                row,
                where: 'usercropid = ?',
                whereArgs: [cropId],
              );
              debugPrint(
                '📝 Updated crop from server: $cropId (${crop['plant_name']})',
              );
            } else {
              debugPrint('⏭️ Skipping locally modified crop: $cropId');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error applying crop: $e');
          continue;
        }
      }
    });

    debugPrint('✅ Applied ${crops.length} crops from server');
  }

  // ==================== SYNC TIMESTAMP MANAGEMENT ====================

  Future<void> _updateLastHistorySyncTimestamp(String timestamp) async {
    try {
      await _storage.write(key: 'crop_history_last_sync', value: timestamp);
      debugPrint('✅ Saved history sync timestamp: $timestamp');
    } catch (e) {
      debugPrint('⚠️ Error saving history sync timestamp: $e');
    }
  }
}
