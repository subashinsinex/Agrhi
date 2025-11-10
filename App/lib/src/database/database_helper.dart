import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/constants.dart';
import 'dart:io';
import 'dart:async';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const String baseUrl = AppConstants.baseUrl;

  // API endpoints for each reference table
  static const Map<String, String> tableEndpointMap = {
    'diseases': '$baseUrl/diseaseRemedies/diseases',
    'remedies': '$baseUrl/diseaseRemedies/remedies',
    'plants': '$baseUrl/farmcrop/masters/plants',
    'soil_types': '$baseUrl/farmcrop/masters/soiltypes',
    'crop_types': '$baseUrl/farmcrop/masters/croptypes',
    'water_src': '$baseUrl/farmcrop/masters/watersources',
    'irrigation_method': '$baseUrl/farmcrop/masters/irrigations',
    'diseases_plants': '$baseUrl/diseaseRemedies/disease-plants',
    'disease_remedy': '$baseUrl/diseaseRemedies/disease-remedies',
  };

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('agrhi_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Track reference-table versions
    await db.execute('''
      CREATE TABLE reference_table_versions (
        ref_table_name TEXT PRIMARY KEY,
        updated_at TEXT
      )
    ''');

    // Reference tables
    await db.execute('''
      CREATE TABLE crop_types (
        crop_type_id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE plants (
        plant_id TEXT PRIMARY KEY,
        plant_name TEXT NOT NULL,
        crop_type_id TEXT NOT NULL,
        water_requirement TEXT NOT NULL,
        FOREIGN KEY (crop_type_id) REFERENCES crop_types(crop_type_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE soil_types (
        soil_type_id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE water_src (
        water_src_id TEXT PRIMARY KEY,
        source TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE irrigation_method (
        irrigation_id TEXT PRIMARY KEY,
        method_name TEXT NOT NULL UNIQUE
      )
    ''');

    // Core user data tables
    await db.execute('''
      CREATE TABLE farms (
        farm_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        farm_size REAL NOT NULL,
        survey_number TEXT NOT NULL UNIQUE,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_crops (
        user_crop_id TEXT PRIMARY KEY,
        farm_id TEXT NOT NULL,
        plant_id TEXT NOT NULL,
        planting_date TEXT NOT NULL,
        harvest_date TEXT,
        duration REAL,
        field_size REAL,
        soil_type_id TEXT NOT NULL,
        status TEXT CHECK (status IN ('Growing', 'Harvested', 'Planted')),
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (farm_id) REFERENCES farms(farm_id),
        FOREIGN KEY (plant_id) REFERENCES plants(plant_id),
        FOREIGN KEY (soil_type_id) REFERENCES soil_types(soil_type_id)
      )
    ''');

    // Disease-related reference tables
    await db.execute('''
      CREATE TABLE diseases (
        disease_id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        severity TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE diseases_plants (
        disease_id TEXT NOT NULL,
        plant_id TEXT NOT NULL,
        PRIMARY KEY (disease_id, plant_id),
        FOREIGN KEY (disease_id) REFERENCES diseases(disease_id),
        FOREIGN KEY (plant_id) REFERENCES plants(plant_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE remedies (
        remedy_id TEXT PRIMARY KEY,
        remedy TEXT NOT NULL,
        prevention TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE disease_remedy (
        disease_id TEXT NOT NULL,
        remedy_id TEXT NOT NULL,
        PRIMARY KEY (disease_id, remedy_id),
        FOREIGN KEY (disease_id) REFERENCES diseases(disease_id),
        FOREIGN KEY (remedy_id) REFERENCES remedies(remedy_id)
      )
    ''');

    // Images and analysis
    await db.execute('''
      CREATE TABLE images (
        image_id TEXT PRIMARY KEY,
        crop_id TEXT NOT NULL,
        local_path TEXT NOT NULL,
        server_image_url TEXT,
        is_uploaded INTEGER DEFAULT 0,
        created_at TEXT,
        FOREIGN KEY (crop_id) REFERENCES user_crops(user_crop_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE disease_analysis_results (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        crop_id TEXT NOT NULL,
        image_id TEXT NOT NULL,
        disease_id TEXT NOT NULL,
        remedy_id TEXT NOT NULL,
        confidence REAL,
        created_at TEXT,
        is_uploaded INTEGER DEFAULT 0,
        is_dirty INTEGER DEFAULT 1,
        FOREIGN KEY (crop_id) REFERENCES user_crops(user_crop_id),
        FOREIGN KEY (image_id) REFERENCES images(image_id),
        FOREIGN KEY (disease_id) REFERENCES diseases(disease_id),
        FOREIGN KEY (remedy_id) REFERENCES remedies(remedy_id)
      )
    ''');

    // Initialize reference table version rows
    final tables = [
      'diseases',
      'remedies',
      'plants',
      'soil_types',
      'crop_types',
      'water_src',
      'irrigation_method',
      'diseases_plants',
      'disease_remedy',
    ];
    for (var table in tables) {
      await db.insert('reference_table_versions', {
        'ref_table_name': table,
        'updated_at': '2000-01-01T00:00:00Z',
      });
    }

    print('✅ All database tables created successfully');
  }

  // ============= IMAGE OPS =============

  Future<String> insertImage({
    required String cropId,
    required String localPath,
  }) async {
    final db = await database;
    final imageId = const Uuid().v4();

    await db.insert('images', {
      'image_id': imageId,
      'crop_id': cropId,
      'local_path': localPath,
      'server_image_url': null,
      'is_uploaded': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    print('✅ Image inserted: $imageId');
    return imageId;
  }

  // ============= ANALYSIS OPS =============

  Future<String> insertDiseaseAnalysis({
    required String userId,
    required String cropId,
    required String imageId,
    required String diseaseId,
    required String remedyId,
    required double confidence,
  }) async {
    final db = await database;
    final analysisId = const Uuid().v4();

    await db.insert('disease_analysis_results', {
      'id': analysisId,
      'user_id': userId,
      'crop_id': cropId,
      'image_id': imageId,
      'disease_id': diseaseId,
      'remedy_id': remedyId,
      'confidence': confidence,
      'created_at': DateTime.now().toIso8601String(),
      'is_uploaded': 0,
      'is_dirty': 1,
    });

    print('✅ Analysis inserted: $analysisId');
    return analysisId;
  }

  Future<List<Map<String, dynamic>>> getPendingAnalyses() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        dar.*,
        d.name as disease_name,
        d.severity,
        r.remedy,
        r.prevention,
        i.local_path,
        uc.status as crop_status,
        uc.field_size
      FROM disease_analysis_results dar
      LEFT JOIN diseases d ON dar.disease_id = d.disease_id
      LEFT JOIN remedies r ON dar.remedy_id = r.remedy_id
      LEFT JOIN images i ON dar.image_id = i.image_id
      LEFT JOIN user_crops uc ON dar.crop_id = uc.user_crop_id
      WHERE dar.is_dirty = 1 OR dar.is_uploaded = 0
      ORDER BY dar.created_at DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getUserAnalyses(String userId) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT 
        dar.*,
        d.name as disease_name,
        d.severity,
        r.remedy,
        r.prevention,
        i.local_path,
        i.server_image_url,
        uc.status as crop_status,
        uc.field_size
      FROM disease_analysis_results dar
      LEFT JOIN diseases d ON dar.disease_id = d.disease_id
      LEFT JOIN remedies r ON dar.remedy_id = r.remedy_id
      LEFT JOIN images i ON dar.image_id = i.image_id
      LEFT JOIN user_crops uc ON dar.crop_id = uc.user_crop_id
      WHERE dar.user_id = ?
      ORDER BY dar.created_at DESC
    ''',
      [userId],
    );
  }

  Future<Map<String, dynamic>?> getAnalysisById(String analysisId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 
        dar.*,
        d.name as disease_name,
        d.severity,
        r.remedy,
        r.prevention,
        i.local_path,
        i.server_image_url,
        uc.status as crop_status
      FROM disease_analysis_results dar
      LEFT JOIN diseases d ON dar.disease_id = d.disease_id
      LEFT JOIN remedies r ON dar.remedy_id = r.remedy_id
      LEFT JOIN images i ON dar.image_id = i.image_id
      LEFT JOIN user_crops uc ON dar.crop_id = uc.user_crop_id
      WHERE dar.id = ?
    ''',
      [analysisId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> markAsUploaded(String analysisId, String? serverImageUrl) async {
    final db = await database;
    await db.update(
      'disease_analysis_results',
      {'is_uploaded': 1, 'is_dirty': 0},
      where: 'id = ?',
      whereArgs: [analysisId],
    );

    if (serverImageUrl != null) {
      await db.update(
        'images',
        {'server_image_url': serverImageUrl, 'is_uploaded': 1},
        where:
            'image_id = (SELECT image_id FROM disease_analysis_results WHERE id = ?)',
        whereArgs: [analysisId],
      );
    }

    print('✅ Analysis marked as uploaded: $analysisId');
  }

  // ============= CROPS OPS =============

  Future<List<Map<String, dynamic>>> getCropsByFarm(String farmId) async {
    final db = await database;
    return await db.query(
      'user_crops',
      where: 'farm_id = ? AND is_active = 1',
      whereArgs: [farmId],
    );
  }

  Future<Map<String, dynamic>?> getUserCrop(String cropId) async {
    final db = await database;
    final result = await db.query(
      'user_crops',
      where: 'user_crop_id = ?',
      whereArgs: [cropId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // ============= VERSION OPS =============

  Future<List<Map<String, dynamic>>> getReferenceTableVersions() async {
    final db = await database;
    return await db.query('reference_table_versions');
  }

  Future<Map<String, dynamic>?> getTableVersion(String tableName) async {
    final db = await database;
    final result = await db.query(
      'reference_table_versions',
      where: 'ref_table_name = ?',
      whereArgs: [tableName],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> updateTableVersion(String tableName, String updatedAt) async {
    final db = await database;
    await db.update(
      'reference_table_versions',
      {'updated_at': updatedAt},
      where: 'ref_table_name = ?',
      whereArgs: [tableName],
    );
    print('✅ Updated version for $tableName: $updatedAt');
  }

  // ============= SMART SYNC (CLIENT-SIDE) =============

  Future<Map<String, String>> fetchServerTableVersions(
    String accessToken,
  ) async {
    try {
      print('🔄 Fetching server table versions...');
      final response = await http
          .get(
            Uri.parse('$baseUrl/users/rtv'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final serverVersions = <String, String>{};
        for (var item in data) {
          serverVersions[item['ref_table_name']] = item['updated_at'];
        }
        print('✅ Got server versions: ${serverVersions.length} tables');
        return serverVersions;
      } else {
        print('❌ Failed to fetch versions: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('❌ Error fetching server versions: $e');
      return {};
    }
  }

  Future<Map<String, bool>> compareVersionsClientSide(
    Map<String, String> serverVersions,
  ) async {
    try {
      print('🔍 Comparing versions locally...');
      final localVersions = await getReferenceTableVersions();
      final needsUpdate = <String, bool>{};

      for (var local in localVersions) {
        final tableName = local['ref_table_name'] as String;
        final localTime = DateTime.parse(local['updated_at'] as String);
        final serverTimeStr =
            serverVersions[tableName] ?? '2000-01-01T00:00:00Z';
        final serverTime = DateTime.parse(serverTimeStr);

        needsUpdate[tableName] = serverTime.isAfter(localTime);

        if (needsUpdate[tableName]!) {
          print(
            '📥 $tableName needs update (local: ${localTime.toIso8601String().substring(0, 10)}, server: ${serverTime.toIso8601String().substring(0, 10)})',
          );
        } else {
          print('✅ $tableName is current');
        }
      }

      return needsUpdate;
    } catch (e) {
      print('❌ Version comparison error: $e');
      return {};
    }
  }

  // Extract records from either list payloads or wrapped maps
  List<dynamic> _extractRecords(dynamic data) {
    try {
      print('📋 Response data type: ${data.runtimeType}');
      if (data is List) {
        print('✅ Direct array response: ${data.length} items');
        return data;
      }
      if (data is Map<String, dynamic>) {
        // Common wrappers
        if (data.containsKey('data') && data['data'] is List) {
          print(
            '✅ Found in "data" key: ${(data['data'] as List).length} items',
          );
          return data['data'];
        }
        if (data.containsKey('records') && data['records'] is List) {
          print(
            '✅ Found in "records" key: ${(data['records'] as List).length} items',
          );
          return data['records'];
        }
        // Fallback: treat map values as records
        final vals = data.values.toList();
        print('✅ Map values used as records: ${vals.length} items');
        return vals;
      }
      return [];
    } catch (e) {
      print('❌ Extract error: $e');
      return [];
    }
  }

  // Fetch one table and update local DB
  Future<bool> _fetchAndUpdateTable(
    String tableName,
    String accessToken,
  ) async {
    try {
      print('📥 Fetching $tableName from server...');

      final endpoint = tableEndpointMap[tableName];
      if (endpoint == null) {
        print('❌ No endpoint found for $tableName');
        return false;
      }

      print('🔗 Endpoint: $endpoint');

      final response = await http
          .get(
            Uri.parse(endpoint),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 15));

      print('📊 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('📄 Response length: ${response.body.length} chars');

        final data = jsonDecode(response.body);
        final List<dynamic> records = _extractRecords(data);

        if (records.isEmpty) {
          print('⚠️ No records found in response for $tableName');
          return true;
        }

        // IMPORTANT: Only read updatedAt from map payloads
        String updatedAt = DateTime.now().toIso8601String();
        if (data is Map) {
          updatedAt = (data['updated_at'] ?? data['lastUpdated'] ?? updatedAt)
              .toString();
        }

        // Pass records directly; sync methods accept List<dynamic>
        switch (tableName) {
          case 'diseases':
            await syncDiseases(records);
            break;
          case 'remedies':
            await syncRemedies(records);
            break;
          case 'plants':
            await syncPlants(records);
            break;
          case 'soil_types':
            await syncSoilTypes(records);
            break;
          case 'crop_types':
            await syncCropTypes(records);
            break;
          case 'water_src':
            await syncWaterSources(records);
            break;
          case 'irrigation_method':
            await syncIrrigationMethods(records);
            break;
          case 'diseases_plants':
            await syncDiseasesPlants(records);
            break;
          case 'disease_remedy':
            await syncDiseaseRemedy(records);
            break;
        }

        await updateTableVersion(tableName, updatedAt);
        print('✅ Updated $tableName: ${records.length} records synced');
        return true;
      } else if (response.statusCode == 404) {
        print('ℹ️ Endpoint not found: ${response.statusCode}');
        return true;
      } else {
        print('⚠️ Failed to fetch $tableName: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error fetching $tableName: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> smartSyncCatalogs(String accessToken) async {
    try {
      print('\n🔄 ========== SMART SYNC STARTING ==========');

      final serverVersions = await fetchServerTableVersions(accessToken);
      if (serverVersions.isEmpty) {
        print('⚠️ Could not fetch server versions');
        return {'success': false, 'message': 'Failed to get server versions'};
      }

      final needsUpdate = await compareVersionsClientSide(serverVersions);
      if (needsUpdate.isEmpty) {
        print('✅ All catalogs up-to-date');
        return {
          'success': true,
          'message': 'All catalogs up-to-date',
          'updated': 0,
        };
      }

      int updatedCount = 0;
      List<String> failedTables = [];

      for (var entry in needsUpdate.entries) {
        if (entry.value) {
          final success = await _fetchAndUpdateTable(entry.key, accessToken);
          if (success) {
            updatedCount++;
          } else {
            failedTables.add(entry.key);
          }
        }
      }

      print('\n✅ ========== SMART SYNC COMPLETE ==========');
      print('Updated: $updatedCount, Failed: ${failedTables.length}\n');

      return {
        'success': failedTables.isEmpty,
        'message': 'Updated $updatedCount tables',
        'updated': updatedCount,
        'failed': failedTables,
      };
    } catch (e) {
      print('❌ Smart sync error: $e');
      return {'success': false, 'message': 'Sync failed: $e'};
    }
  }

  // ============= CATALOG SYNC (defensive, dynamic) =============

  Future<void> syncDiseases(List<dynamic> diseases) async {
    final db = await database;
    await db.delete('diseases');
    for (var item in diseases) {
      try {
        if (item is! Map) continue;
        final rec = item;
        await db.insert('diseases', {
          'disease_id': (rec['disease_id'] ?? '').toString(),
          'name': (rec['name'] ?? '').toString(),
          'severity': (rec['severity'] ?? 'Unknown').toString(),
        });
      } catch (e) {
        print('⚠️ Error inserting disease: $e');
      }
    }
    print('✅ ${diseases.length} diseases synced');
  }

  Future<void> syncRemedies(List<dynamic> remedies) async {
    final db = await database;
    await db.delete('remedies');
    for (var item in remedies) {
      try {
        if (item is! Map) continue;
        final rec = item;
        await db.insert('remedies', {
          'remedy_id': (rec['remedy_id'] ?? '').toString(),
          'remedy': (rec['remedy'] ?? '').toString(),
          'prevention': (rec['prevention'] ?? '').toString(),
        });
      } catch (e) {
        print('⚠️ Error inserting remedy: $e');
      }
    }
    print('✅ ${remedies.length} remedies synced');
  }

  Future<void> syncPlants(List<dynamic> plants) async {
    final db = await database;
    await db.delete('plants');
    for (var item in plants) {
      try {
        if (item is! Map) continue;
        final rec = item;
        await db.insert('plants', {
          'plant_id': (rec['plant_id'] ?? '').toString(),
          'plant_name': (rec['plant_name'] ?? '').toString(),
          'crop_type_id': (rec['crop_type_id'] ?? '').toString(),
          'water_requirement': (rec['water_requirement'] ?? 'Medium')
              .toString(),
        });
      } catch (e) {
        print('⚠️ Error inserting plant: $e');
      }
    }
    print('✅ ${plants.length} plants synced');
  }

  Future<void> syncSoilTypes(List<dynamic> soilTypes) async {
    final db = await database;
    await db.delete('soil_types');
    for (var item in soilTypes) {
      try {
        if (item is! Map) continue;
        final rec = item;
        await db.insert('soil_types', {
          'soil_type_id': (rec['soil_type_id'] ?? '').toString(),
          'name': (rec['name'] ?? '').toString(),
        });
      } catch (e) {
        print('⚠️ Error inserting soil type: $e');
      }
    }
    print('✅ ${soilTypes.length} soil types synced');
  }

  Future<void> syncCropTypes(List<dynamic> cropTypes) async {
    final db = await database;
    await db.delete('crop_types');
    for (var item in cropTypes) {
      try {
        if (item is! Map) continue;
        final rec = item;
        await db.insert('crop_types', {
          'crop_type_id': (rec['crop_type_id'] ?? '').toString(),
          'name': (rec['name'] ?? '').toString(),
        });
      } catch (e) {
        print('⚠️ Error inserting crop type: $e');
      }
    }
    print('✅ ${cropTypes.length} crop types synced');
  }

  Future<void> syncWaterSources(List<dynamic> waterSources) async {
    final db = await database;
    await db.delete('water_src');
    for (var item in waterSources) {
      try {
        if (item is! Map) continue;
        final rec = item;
        await db.insert('water_src', {
          'water_src_id': (rec['water_src_id'] ?? '').toString(),
          'source': (rec['source'] ?? '').toString(),
        });
      } catch (e) {
        print('⚠️ Error inserting water source: $e');
      }
    }
    print('✅ ${waterSources.length} water sources synced');
  }

  Future<void> syncIrrigationMethods(List<dynamic> methods) async {
    final db = await database;
    await db.delete('irrigation_method');
    for (var item in methods) {
      try {
        if (item is! Map) continue;
        final rec = item;
        await db.insert('irrigation_method', {
          'irrigation_id': (rec['irrigation_id'] ?? '').toString(),
          'method_name': (rec['method_name'] ?? '').toString(),
        });
      } catch (e) {
        print('⚠️ Error inserting irrigation method: $e');
      }
    }
    print('✅ ${methods.length} irrigation methods synced');
  }

  Future<void> syncDiseasesPlants(List<dynamic> diseasesPlantsData) async {
    final db = await database;
    await db.delete('diseases_plants');
    for (var item in diseasesPlantsData) {
      try {
        if (item is! Map) continue;
        final rec = item;
        await db.insert('diseases_plants', {
          'disease_id': (rec['disease_id'] ?? '').toString(),
          'plant_id': (rec['plant_id'] ?? '').toString(),
        });
      } catch (e) {
        print('⚠️ Error inserting disease-plant: $e');
      }
    }
    print('✅ ${diseasesPlantsData.length} disease-plant mappings synced');
  }

  Future<void> syncDiseaseRemedy(List<dynamic> diseaseRemedyData) async {
    final db = await database;
    await db.delete('disease_remedy');
    for (var item in diseaseRemedyData) {
      try {
        if (item is! Map) continue;
        final rec = item;
        await db.insert('disease_remedy', {
          'disease_id': (rec['disease_id'] ?? '').toString(),
          'remedy_id': (rec['remedy_id'] ?? '').toString(),
        });
      } catch (e) {
        print('⚠️ Error inserting disease-remedy: $e');
      }
    }
    print('✅ ${diseaseRemedyData.length} disease-remedy mappings synced');
  }

  // ============= USER DATA SYNC =============

  Future<Map<String, dynamic>> syncPendingToServer(String accessToken) async {
    print('🔄 Starting user data sync to server...');
    try {
      final pending = await getPendingAnalyses();

      if (pending.isEmpty) {
        print('ℹ️ No pending analyses to sync');
        return {
          'success': true,
          'message': 'No pending',
          'synced': 0,
          'failed': 0,
        };
      }

      int successCount = 0;
      int failedCount = 0;
      List<String> failedIds = [];

      for (var analysis in pending) {
        try {
          final uploaded = await _uploadAnalysisToServer(analysis, accessToken);
          if (uploaded) {
            await markAsUploaded(analysis['id'], analysis['server_image_url']);
            successCount++;
            print('✅ Synced analysis: ${analysis['id']}');
          } else {
            failedCount++;
            failedIds.add(analysis['id']);
          }
        } catch (e) {
          failedCount++;
          failedIds.add(analysis['id']);
          print('❌ Error syncing ${analysis['id']}: $e');
        }
      }

      return {
        'success': failedCount == 0,
        'synced': successCount,
        'failed': failedCount,
        'failedIds': failedIds,
      };
    } catch (e) {
      print('❌ Sync error: $e');
      return {
        'success': false,
        'message': 'Sync failed: $e',
        'synced': 0,
        'failed': 0,
      };
    }
  }

  Future<bool> _uploadAnalysisToServer(
    Map<String, dynamic> analysis,
    String accessToken,
  ) async {
    try {
      final imagePath = analysis['local_path'] as String?;
      if (imagePath == null || !File(imagePath).existsSync()) {
        print('⚠️ Image file not found: $imagePath');
        return false;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/disease/analysis/sync'),
      );

      request.headers['Authorization'] = 'Bearer $accessToken';
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));

      request.fields.addAll({
        'analysisId': analysis['id'].toString(),
        'userId': analysis['user_id'].toString(),
        'cropId': analysis['crop_id'].toString(),
        'diseaseId': analysis['disease_id'].toString(),
        'remedyId': analysis['remedy_id'].toString(),
        'confidence': analysis['confidence'].toString(),
        'createdAt': analysis['created_at'].toString(),
      });

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Upload successful: ${analysis['id']}');
        return true;
      } else {
        print('❌ Upload failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return false;
    }
  }

  // ============= UTILS =============

  Future<Map<String, dynamic>> getSyncStatus() async {
    final pending = await getPendingAnalyses();
    final stats = await getDatabaseStats();
    return {
      'pendingCount': pending.length,
      'totalAnalyses': stats['analyses'],
      'totalImages': stats['images'],
    };
  }

  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;

    final analysisCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM disease_analysis_results'),
        ) ??
        0;
    final imagesCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM images'),
        ) ??
        0;
    final cropsCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM user_crops WHERE is_active = 1',
          ),
        ) ??
        0;
    final diseasesCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM diseases'),
        ) ??
        0;

    return {
      'analyses': analysisCount,
      'images': imagesCount,
      'crops': cropsCount,
      'diseases': diseasesCount,
    };
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('disease_analysis_results');
    await db.delete('images');
    print('⚠️ All user data cleared');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
