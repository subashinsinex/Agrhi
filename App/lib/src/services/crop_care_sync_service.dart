// lib/src/services/crop_care_sync_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../../utils/constants.dart';

/// Service for two-way sync of farms and crops
class CropCareSyncService {
  static final CropCareSyncService instance = CropCareSyncService._init();
  CropCareSyncService._init();

  final DatabaseHelper _db = DatabaseHelper.instance;
  static const String baseUrl = AppConstants.baseUrl;

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
    try {
      debugPrint('🔄 Starting CropCare full sync...');

      final syncResult = await performTwoWaySync(accessToken);

      return {
        'success': syncResult['success'],
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
    }
  }

  // ==================== TWO-WAY SYNC ====================

  Future<Map<String, dynamic>> performTwoWaySync(String accessToken) async {
    try {
      debugPrint('🔄 Starting CropCare two-way sync...');

      // Upload first, then download
      final farmUploadResult = await uploadPendingFarms(accessToken);
      final cropUploadResult = await uploadPendingCrops(accessToken);
      final farmDownloadResult = await downloadServerFarms(accessToken);
      final cropDownloadResult = await downloadServerCrops(accessToken);

      final allSuccess =
          farmUploadResult['success'] &&
          cropUploadResult['success'] &&
          farmDownloadResult['success'] &&
          cropDownloadResult['success'];

      return {
        'success': allSuccess,
        'farmUpload': farmUploadResult,
        'cropUpload': cropUploadResult,
        'farmDownload': farmDownloadResult,
        'cropDownload': cropDownloadResult,
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

          String endpoint;
          Map<String, dynamic> payload;
          http.Response response;

          if (wasUploaded) {
            // ✅ UPDATE existing farm with PUT
            endpoint = '$baseUrl/farmcrop/updatefarms/$farmId';
            payload = {
              'farm_size': farmWithRelations['farmsize'],
              'survey_number': farmWithRelations['surveynumber'],
              'soil_type_ids': farmWithRelations['soil_type_ids'] ?? [],
              'irrigation_ids': farmWithRelations['irrigation_ids'] ?? [],
              'water_src_ids': farmWithRelations['water_source_ids'] ?? [],
            };
            debugPrint('📝 Updating farm $farmId');

            response = await http
                .put(
                  Uri.parse(endpoint),
                  headers: {
                    'Authorization': 'Bearer $accessToken',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode(payload),
                )
                .timeout(const Duration(seconds: 30));
          } else {
            // ✅ ADD new farm with POST
            endpoint = '$baseUrl/farmcrop/addfarmsbyid';
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

            response = await http
                .post(
                  Uri.parse(endpoint),
                  headers: {
                    'Authorization': 'Bearer $accessToken',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode(payload),
                )
                .timeout(const Duration(seconds: 30));
          }

          debugPrint(
            '📡 Farm ${wasUploaded ? "update" : "add"} response: ${response.statusCode}',
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            await _db.markFarmAsUploaded(farmId);
            uploadedCount++;
            uploadedIds.add(farmId);
            debugPrint('✅ Farm ${wasUploaded ? "updated" : "added"}: $farmId');
          } else if (response.statusCode == 500 || response.statusCode == 409) {
            try {
              final errorData = jsonDecode(response.body);
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
                debugPrint('❌ Upload failed for $farmId: ${response.body}');
              }
            } catch (e) {
              debugPrint('❌ Upload failed for $farmId: ${response.body}');
            }
          } else {
            debugPrint('❌ Upload failed for $farmId: ${response.body}');
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

          String endpoint;
          Map<String, dynamic> payload;
          http.Response response;

          if (wasUploaded) {
            // ✅ UPDATE existing crop with PUT
            endpoint = '$baseUrl/farmcrop/updatecrops/$cropId';
            payload = {
              'farm_id': crop['farmid'],
              'plant_id': crop['plantid'],
              'planting_date': crop['plantingdate'],
              'harvest_date': crop['harvestdate'],
              'field_size': crop['fieldsize'],
              'status': crop['status'],
              'is_active': crop['isactive'] == 1,
            };
            debugPrint('📝 Updating crop $cropId');

            response = await http
                .put(
                  Uri.parse(endpoint),
                  headers: {
                    'Authorization': 'Bearer $accessToken',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode(payload),
                )
                .timeout(const Duration(seconds: 30));
          } else {
            // ✅ ADD new crop with POST - SEND LOCAL CROP ID
            endpoint = '$baseUrl/farmcrop/addcrops';
            payload = {
              'user_crop_id': cropId, // ✅✅✅ SEND LOCAL ID TO SERVER
              'farm_id': crop['farmid'],
              'plant_id': crop['plantid'],
              'planting_date': crop['plantingdate'],
              'harvest_date': crop['harvestdate'],
              'field_size': crop['fieldsize'],
              'status': crop['status'],
              'is_active': crop['isactive'] == 1,
            };
            debugPrint(
              '➕ Adding new crop $cropId (sending local ID to server)',
            );

            response = await http
                .post(
                  Uri.parse(endpoint),
                  headers: {
                    'Authorization': 'Bearer $accessToken',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode(payload),
                )
                .timeout(const Duration(seconds: 30));
          }

          debugPrint(
            '📡 Crop ${wasUploaded ? "update" : "add"} response: ${response.statusCode}',
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            await _db.markCropAsUploaded(cropId);
            uploadedCount++;
            uploadedIds.add(cropId);
            debugPrint('✅ Crop ${wasUploaded ? "updated" : "added"}: $cropId');
          } else if (response.statusCode == 500 || response.statusCode == 409) {
            try {
              final errorData = jsonDecode(response.body);
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
                debugPrint('❌ Upload failed for $cropId: ${response.body}');
              }
            } catch (e) {
              debugPrint('❌ Upload failed for $cropId: ${response.body}');
            }
          } else {
            debugPrint('❌ Upload failed for $cropId: ${response.body}');
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

  // ==================== DOWNLOAD ====================

  Future<Map<String, dynamic>> downloadServerFarms(String accessToken) async {
    try {
      final userId = await _storage.read(key: 'user_id');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      final uri = Uri.parse('$baseUrl/farmcrop/farms/$userId');

      debugPrint('📥 Downloading all farms for user $userId');

      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(const Duration(seconds: 30));

      debugPrint('📡 Farm download response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

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
        'message': 'Download failed: ${response.statusCode}',
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
          final uri = Uri.parse('$baseUrl/farmcrop/crops/$farmId');

          debugPrint('📥 Downloading crops for farm $farmId');

          final response = await http
              .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);

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

            // ✅ FIXED: Add farm_id to each crop since server doesn't provide it
            for (var crop in cropsList) {
              if (crop is Map<String, dynamic>) {
                crop['farm_id'] = farmId; // Inject the farm_id
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

          // Look up by surveynumber (UNIQUE column)
          final existingFarm = await txn.query(
            'farms',
            where: 'surveynumber = ?',
            whereArgs: [surveyNumber],
            limit: 1,
          );
          String farmId;
          if (existingFarm.isEmpty) {
            // No such farm: insert, use server farmid
            farmId = farmIdFromServer;
            await txn.insert('farms', {
              'farmid': farmId,
              'farmsize': farmSize,
              'surveynumber': surveyNumber,
              'createdat': createdAt,
              'isuploaded': 1,
              'isdirty': 0,
            });
            debugPrint('➕ Added farm from server: $farmId');
          } else {
            // Exists: ONLY update other fields, NOT farmid
            farmId = existingFarm.first['farmid'].toString();
            await txn.update(
              'farms',
              {
                'farmsize': farmSize,
                'surveynumber': surveyNumber,
                'createdat': createdAt,
                'isuploaded': 1,
                'isdirty': 0,
              },
              where: 'surveynumber = ?',
              whereArgs: [surveyNumber],
            );
            debugPrint(
              '📝 Updated farm (kept farmid=$farmId) for surveynumber $surveyNumber',
            );
          }

          // Relation handling, using the matched farm ID above
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
              if (result.isNotEmpty)
                soilTypeIds.add(result.first['soiltypeid'].toString());
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
              if (result.isNotEmpty)
                irrigationIds.add(result.first['irrigationid'].toString());
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
              if (result.isNotEmpty)
                waterSourceIds.add(result.first['watersrcid'].toString());
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
          for (final soilTypeId in soilTypeIds) {
            try {
              await txn.insert('farm_soiltypes', {
                'farm_id': farmId,
                'soil_type_id': soilTypeId,
              });
            } catch (_) {}
          }
          for (final irrigationId in irrigationIds) {
            try {
              await txn.insert('farm_irrigations', {
                'farm_id': farmId,
                'irrigation_id': irrigationId,
              });
            } catch (_) {}
          }
          for (final waterSourceId in waterSourceIds) {
            try {
              await txn.insert('farm_watersources', {
                'farm_id': farmId,
                'water_src_id': waterSourceId,
              });
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('⚠️ Error processing farm: $e');
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
          // Get crop ID
          String? cropId = crop['user_crop_id'] ?? crop['usercropid'];

          // ✅ Get farm_id (now injected from parent loop)
          final farmIdFromServer = crop['farm_id'] ?? crop['farmid'];
          if (farmIdFromServer == null) {
            debugPrint(
              '⚠️ Skipping crop without farm_id: ${crop['plant_name']}',
            );
            continue;
          }
          final farmId = farmIdFromServer.toString();

          // Look up plant_id by plant_name
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
            debugPrint(
              '⚠️ Skipping crop without plant_id for ${crop['plant_name']}',
            );
            continue;
          }

          final plantingDate = crop['planting_date'] ?? crop['plantingdate'];

          // If no crop ID, find existing OR generate new UUID
          if (cropId == null) {
            final existing = await txn.query(
              'usercrops',
              where: 'farmid = ? AND plantid = ? AND plantingdate = ?',
              whereArgs: [farmId, plantId, plantingDate],
              limit: 1,
            );

            if (existing.isNotEmpty) {
              cropId = existing.first['usercropid'].toString();
              debugPrint('ℹ️ Found existing crop: $cropId');
            } else {
              cropId = const Uuid().v4();
              debugPrint(
                'ℹ️ Generated new crop ID: $cropId for ${crop['plant_name']}',
              );
            }
          }

          // ✅ Handle NULL soil_type_id - get from farm
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
                debugPrint(
                  '❌ No soil type available, skipping ${crop['plant_name']}',
                );
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
            'usercropid': cropId.toString(),
            'farmid': farmId,
            'plantid': plantId.toString(),
            'plantingdate': plantingDate,
            'harvestdate': crop['harvest_date'] ?? crop['harvestdate'],
            'duration': crop['duration'],
            'fieldsize': crop['field_size'] ?? crop['fieldsize'],
            'soiltypeid': soilTypeId,
            'status': crop['status'] ?? 'Planted',
            'isactive': _toBoolInt(crop['is_active'] ?? crop['isactive']),
            'createdat':
                crop['created_at'] ??
                crop['createdat'] ??
                DateTime.now().toIso8601String(),
            'isuploaded': 1,
            'isdirty': 0,
          };

          if (exists.isEmpty) {
            await txn.insert('usercrops', row);
            debugPrint(
              '➕ Added crop from server: $cropId (${crop['plant_name']})',
            );
          } else {
            await txn.update(
              'usercrops',
              row,
              where: 'usercropid = ?',
              whereArgs: [cropId],
            );
            debugPrint(
              '📝 Updated crop from server: $cropId (${crop['plant_name']})',
            );
          }
        } catch (e) {
          debugPrint('⚠️ Error processing crop ${crop['plant_name']}: $e');
          continue;
        }
      }
    });

    debugPrint('✅ Applied ${crops.length} crops from server');
  }

  // ==================== SYNC TIMESTAMPS ====================

  Future<String?> _getLastFarmSyncTimestamp() async {
    try {
      return await _storage.read(key: 'farm_last_sync');
    } catch (e) {
      debugPrint('❌ Error reading farm sync timestamp: $e');
      return null;
    }
  }

  Future<void> _updateLastFarmSyncTimestamp(String? timestamp) async {
    if (timestamp == null) return;
    try {
      await _storage.write(key: 'farm_last_sync', value: timestamp);
      debugPrint('✅ Saved farm sync timestamp: $timestamp');
    } catch (e) {
      debugPrint('❌ Error saving farm sync timestamp: $e');
    }
  }

  Future<String?> _getLastCropSyncTimestamp() async {
    try {
      return await _storage.read(key: 'crop_last_sync');
    } catch (e) {
      debugPrint('❌ Error reading crop sync timestamp: $e');
      return null;
    }
  }

  Future<void> _updateLastCropSyncTimestamp(String? timestamp) async {
    if (timestamp == null) return;
    try {
      await _storage.write(key: 'crop_last_sync', value: timestamp);
      debugPrint('✅ Saved crop sync timestamp: $timestamp');
    } catch (e) {
      debugPrint('❌ Error saving crop sync timestamp: $e');
    }
  }

  // ==================== UTILITIES ====================

  Future<Map<String, dynamic>> getSyncStatus() async {
    final pendingFarms = await _db.getPendingFarms();
    final pendingCrops = await _db.getPendingCrops();
    final farmSync = await _getLastFarmSyncTimestamp();
    final cropSync = await _getLastCropSyncTimestamp();

    return {
      'pendingFarms': pendingFarms.length,
      'pendingCrops': pendingCrops.length,
      'lastFarmSync': farmSync,
      'lastCropSync': cropSync,
    };
  }

  Future<void> clearSyncTimestamps() async {
    await _storage.delete(key: 'farm_last_sync');
    await _storage.delete(key: 'crop_last_sync');
    debugPrint('🗑️ Cleared all sync timestamps');
  }

  Future<Map<String, dynamic>> forceFullResync(String accessToken) async {
    debugPrint('🔄 Forcing full resync...');
    await clearSyncTimestamps();
    return await performFullSync(accessToken);
  }
}
