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
    print('DB path: $path');
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        final res = await db.rawQuery('PRAGMA foreign_keys');
        print('FK enforcement: ${res.first.values.first}');
      },
      onCreate: _createDB,
    );
    return db;
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reference_table_versions (
        ref_table_name TEXT PRIMARY KEY,
        updated_at TEXT
      )
    ''');

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

    await db.execute('''
      CREATE TABLE images (
        image_id TEXT PRIMARY KEY,
        local_path TEXT NOT NULL,
        server_image_url TEXT,
        is_uploaded INTEGER DEFAULT 0,
        created_at TEXT
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

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dar_pending ON disease_analysis_results(is_dirty, is_uploaded)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dar_user ON disease_analysis_results(user_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dar_crop ON disease_analysis_results(crop_id)',
    );

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
    print('✅ DB created');
  }

  // ---------- helpers ----------
  String _s(dynamic v) => (v ?? '').toString().trim();
  String _firstNonEmpty(Map rec, List<String> keys) {
    for (final k in keys) {
      final val = rec[k];
      if (val != null && _s(val).isNotEmpty) return _s(val);
    }
    return '';
  }

  // ---------- generic UPSERT ----------
  Future<void> _upsert(
    DatabaseExecutor db,
    String table,
    Map<String, Object?> row,
    String pk,
  ) async {
    final cols = row.keys.toList();
    final placeholders = List.filled(cols.length, '?').join(', ');
    final assignments = cols
        .where((c) => c != pk)
        .map((c) => '$c = excluded.$c')
        .join(', ');
    final sql =
        '''
      INSERT INTO $table (${cols.join(', ')})
      VALUES ($placeholders)
      ON CONFLICT($pk) DO UPDATE SET $assignments
    ''';
    await db.rawInsert(sql, cols.map((c) => row[c]).toList());
  }

  // ---------- snapshot reconcile for parents ----------
  Future<void> _reconcileSnapshot({
    required String table,
    required String pk,
    required List<Map<String, Object?>> rows,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final serverIds = <String>{};
      for (final row in rows) {
        final id = (row[pk] ?? '').toString();
        if (id.isEmpty) continue;
        await _upsert(txn, table, row, pk);
        serverIds.add(id);
      }
      if (serverIds.isEmpty) {
        final n = await txn.delete(table);
        print('🗑️ snapshot cleared $table: $n rows');
      } else {
        final qs = List.filled(serverIds.length, '?').join(', ');
        final n = await txn.delete(
          table,
          where: '$pk NOT IN ($qs)',
          whereArgs: serverIds.toList(),
        );
        if (n > 0) print('🧹 snapshot pruned $table: $n stale rows');
      }
    });
  }

  // ================= IMAGE OPS =================
  Future<String> insertImage({
    String? cropId,
    required String localPath,
  }) async {
    final db = await database;
    final imageId = const Uuid().v4();
    await db.insert('images', {
      'image_id': imageId,
      'local_path': localPath,
      'server_image_url': null,
      'is_uploaded': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    return imageId;
  }

  // ================= ANALYSIS OPS =================
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
    return analysisId;
  }

  String _normalizeLabel(String label) => label.replaceAll('_', ' ').trim();

  Future<String?> findDiseaseIdByLabel(String label) async {
    final db = await database;
    final norm = _normalizeLabel(label);
    final rows = await db.query(
      'diseases',
      columns: ['disease_id'],
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [norm],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first['disease_id'] as String : null;
  }

  Future<String?> findRemedyIdForDisease(String diseaseId) async {
    final db = await database;
    final rows = await db.query(
      'disease_remedy',
      columns: ['remedy_id'],
      where: 'disease_id = ?',
      whereArgs: [diseaseId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first['remedy_id'] as String : null;
  }

  Future<String> saveDetectionUsingCatalog({
    required String userId,
    required String cropId,
    required String detectedLabel,
    required double confidence,
    required String localImagePath,
  }) async {
    final db = await database;

    final diseaseId = await findDiseaseIdByLabel(detectedLabel);
    if (diseaseId == null) {
      throw StateError('Unknown disease label: $detectedLabel');
    }

    final remedyId = await findRemedyIdForDisease(diseaseId);
    if (remedyId == null) {
      throw StateError('No remedy mapping for disease: $diseaseId');
    }

    return await db.transaction((txn) async {
      final imageId = const Uuid().v4();
      await txn.insert('images', {
        'image_id': imageId,
        'local_path': localImagePath,
        'server_image_url': null,
        'is_uploaded': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      final analysisId = const Uuid().v4();
      await txn.insert('disease_analysis_results', {
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
      return analysisId;
    });
  }

  // ================= QUERIES =================
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
    final r = await db.rawQuery(
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
    return r.isNotEmpty ? r.first : null;
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
  }

  // ================= VERSION OPS =================
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
  }

  // ================= SMART SYNC (CLIENT) =================
  Future<Map<String, String>> fetchServerTableVersions(
    String accessToken,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/users/rtv'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 10));
      print('📡 rtv: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final serverVersions = <String, String>{};
        for (var item in data) {
          serverVersions[item['ref_table_name']] = item['updated_at'];
        }
        print('🧾 rtv tables: ${serverVersions.length}');
        return serverVersions;
      }
      return {};
    } catch (e) {
      print('❌ rtv error: $e');
      return {};
    }
  }

  Future<Map<String, bool>> compareVersionsClientSide(
    Map<String, String> serverVersions,
  ) async {
    try {
      final localVersions = await getReferenceTableVersions();
      final needsUpdate = <String, bool>{};
      for (var local in localVersions) {
        final tableName = local['ref_table_name'] as String;
        final localTime = DateTime.parse(local['updated_at'] as String);
        final serverTimeStr =
            serverVersions[tableName] ?? '2000-01-01T00:00:00Z';
        final serverTime = DateTime.parse(serverTimeStr);
        final need = serverTime.isAfter(localTime);
        needsUpdate[tableName] = need;
        print(
          '${need ? '⬇️' : '✅'} $tableName (local: $localTime, server: $serverTime)',
        );
      }
      return needsUpdate;
    } catch (e) {
      print('❌ version compare error: $e');
      return {};
    }
  }

  List<dynamic> _extractRecords(dynamic data) {
    try {
      if (data is List) return data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('data') && data['data'] is List) {
          return data['data'];
        }
        if (data.containsKey('records') && data['records'] is List) {
          return data['records'];
        }
        return data.values.toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> _fetchAndUpdateTable(
    String tableName,
    String accessToken,
  ) async {
    try {
      final endpoint = tableEndpointMap[tableName];
      if (endpoint == null) {
        print('❌ No endpoint for $tableName');
        return false;
      }
      print('🔗 [$tableName] GET $endpoint');
      final t0 = DateTime.now();
      final response = await http
          .get(
            Uri.parse(endpoint),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 15));
      final ms = DateTime.now().difference(t0).inMilliseconds;
      print(
        '📡 [$tableName] ${response.statusCode} in ${ms}ms, ${response.bodyBytes.length} bytes',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> records = _extractRecords(data);
        final preview = records.isNotEmpty && records.first is Map
            ? (records.first as Map).keys.take(6).join(', ')
            : 'n/a';
        print(
          '🧾 [$tableName] records=${records.length}, firstKeys=[$preview]',
        );

        String updatedAt = DateTime.now().toIso8601String();
        if (data is Map) {
          updatedAt = (data['updated_at'] ?? data['lastUpdated'] ?? updatedAt)
              .toString();
        }

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
        print('✅ [$tableName] applied, version=$updatedAt');
        return true;
      } else if (response.statusCode == 404) {
        print('ℹ️ [$tableName] 404 not found; skipping');
        return true;
      }
      print('⚠️ [$tableName] HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ [$tableName] fetch/apply error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> smartSyncCatalogs(String accessToken) async {
    try {
      print('🔄 smartSyncCatalogs starting...');
      final serverVersions = await fetchServerTableVersions(accessToken);
      if (serverVersions.isEmpty) {
        print('⚠️ table versions empty');
        return {'success': false, 'message': 'Failed to get server versions'};
      }
      final needsUpdate = await compareVersionsClientSide(serverVersions);
      if (needsUpdate.isEmpty) {
        print('✅ no table needs update');
        return {
          'success': true,
          'message': 'All catalogs up-to-date',
          'updated': 0,
        };
      }

      int updatedCount = 0;
      final failedTables = <String>[];
      final order = [
        'crop_types',
        'soil_types',
        'remedies',
        'diseases',
        'plants',
        'diseases_plants',
        'disease_remedy',
        'water_src',
        'irrigation_method',
      ];
      for (final table in order) {
        if (needsUpdate[table] == true) {
          final ok = await _fetchAndUpdateTable(table, accessToken);
          if (ok) {
            updatedCount++;
          } else {
            failedTables.add(table);
          }
        }
      }

      print(
        '✅ smartSync done: updated=$updatedCount, failed=${failedTables.length}',
      );
      if (failedTables.isNotEmpty) print('❌ failed: $failedTables');

      return {
        'success': failedTables.isEmpty,
        'message': 'Updated $updatedCount tables',
        'updated': updatedCount,
        'failed': failedTables,
      };
    } catch (e) {
      print('❌ smartSync error: $e');
      return {'success': false, 'message': 'Sync failed: $e'};
    }
  }

  // ================= CATALOG SYNC (parents via reconcile, mappings via rebuild) =================
  Future<void> syncDiseases(List<dynamic> rows) async {
    final mapped = <Map<String, Object?>>[];
    int skip = 0;
    for (final item in rows) {
      if (item is! Map) {
        skip++;
        continue;
      }
      final rec = item;
      final id = _s(rec['disease_id']);
      final name = _s(rec['name']);
      if (id.isEmpty || name.isEmpty) {
        skip++;
        continue;
      }
      mapped.add({
        'disease_id': id,
        'name': name,
        'severity': _s(rec['severity']).isEmpty
            ? 'Unknown'
            : _s(rec['severity']),
      });
    }
    await _reconcileSnapshot(table: 'diseases', pk: 'disease_id', rows: mapped);
    print('✅ diseases reconcile: kept=${mapped.length}, skipped=$skip');
  }

  Future<void> syncRemedies(List<dynamic> rows) async {
    final mapped = <Map<String, Object?>>[];
    int skip = 0;
    for (final item in rows) {
      if (item is! Map) {
        skip++;
        continue;
      }
      final rec = item;
      final id = _s(rec['remedy_id']);
      final remedy = _s(rec['remedy']);
      if (id.isEmpty || remedy.isEmpty) {
        skip++;
        continue;
      }
      mapped.add({
        'remedy_id': id,
        'remedy': remedy,
        'prevention': _s(rec['prevention']),
      });
    }
    await _reconcileSnapshot(table: 'remedies', pk: 'remedy_id', rows: mapped);
    print('✅ remedies reconcile: kept=${mapped.length}, skipped=$skip');
  }

  Future<void> syncPlants(List<dynamic> rows) async {
    final mapped = <Map<String, Object?>>[];
    int skip = 0;
    for (final item in rows) {
      if (item is! Map) {
        skip++;
        continue;
      }
      final rec = item;
      final plantId = _firstNonEmpty(rec, [
        'plant_id',
        'id',
        'uuid',
        'plantId',
      ]);
      final plantName = _firstNonEmpty(rec, [
        'plant_name',
        'name',
        'title',
        'label',
      ]);
      final cropType = _firstNonEmpty(rec, [
        'crop_type_id',
        'cropTypeId',
        'crop_type',
        'cropType',
      ]);
      final waterReq = _firstNonEmpty(rec, [
        'water_requirement',
        'waterRequirement',
        'water',
        'water_req',
      ]);
      if (plantId.isEmpty || plantName.isEmpty || cropType.isEmpty) {
        print(
          '⏭️ plants skip: id="$plantId" name="$plantName" cropType="$cropType" keys=${rec.keys}',
        );
        skip++;
        continue;
      }
      mapped.add({
        'plant_id': plantId,
        'plant_name': plantName,
        'crop_type_id': cropType,
        'water_requirement': waterReq.isEmpty ? 'Medium' : waterReq,
      });
    }
    await _reconcileSnapshot(table: 'plants', pk: 'plant_id', rows: mapped);
    print('✅ plants reconcile: kept=${mapped.length}, skipped=$skip');
  }

  Future<void> syncSoilTypes(List<dynamic> rows) async {
    final mapped = <Map<String, Object?>>[];
    int skip = 0;
    for (final item in rows) {
      if (item is! Map) {
        skip++;
        continue;
      }
      final rec = item;
      final id = _s(rec['soil_type_id']);
      final name = _s(rec['name']);
      if (id.isEmpty || name.isEmpty) {
        skip++;
        continue;
      }
      mapped.add({'soil_type_id': id, 'name': name});
    }
    await _reconcileSnapshot(
      table: 'soil_types',
      pk: 'soil_type_id',
      rows: mapped,
    );
    print('✅ soil_types reconcile: kept=${mapped.length}, skipped=$skip');
  }

  Future<void> syncCropTypes(List<dynamic> rows) async {
    final mapped = <Map<String, Object?>>[];
    int skip = 0;
    for (final item in rows) {
      if (item is! Map) {
        skip++;
        continue;
      }
      final rec = item;
      final id = _s(rec['crop_type_id']);
      final name = _s(rec['name']);
      if (id.isEmpty || name.isEmpty) {
        skip++;
        continue;
      }
      mapped.add({'crop_type_id': id, 'name': name});
    }
    await _reconcileSnapshot(
      table: 'crop_types',
      pk: 'crop_type_id',
      rows: mapped,
    );
    print('✅ crop_types reconcile: kept=${mapped.length}, skipped=$skip');
  }

  Future<void> syncWaterSources(List<dynamic> rows) async {
    final mapped = <Map<String, Object?>>[];
    int skip = 0;
    for (final item in rows) {
      if (item is! Map) {
        skip++;
        continue;
      }
      final rec = item;
      final id = _s(rec['water_src_id']);
      final src = _s(rec['source']);
      if (id.isEmpty || src.isEmpty) {
        skip++;
        continue;
      }
      mapped.add({'water_src_id': id, 'source': src});
    }
    await _reconcileSnapshot(
      table: 'water_src',
      pk: 'water_src_id',
      rows: mapped,
    );
    print('✅ water_src reconcile: kept=${mapped.length}, skipped=$skip');
  }

  Future<void> syncIrrigationMethods(List<dynamic> rows) async {
    final mapped = <Map<String, Object?>>[];
    int skip = 0;
    for (final item in rows) {
      if (item is! Map) {
        skip++;
        continue;
      }
      final rec = item;
      final id = _s(rec['irrigation_id']);
      final name = _s(rec['method_name']);
      if (id.isEmpty || name.isEmpty) {
        skip++;
        continue;
      }
      mapped.add({'irrigation_id': id, 'method_name': name});
    }
    await _reconcileSnapshot(
      table: 'irrigation_method',
      pk: 'irrigation_id',
      rows: mapped,
    );
    print(
      '✅ irrigation_method reconcile: kept=${mapped.length}, skipped=$skip',
    );
  }

  Future<void> syncDiseasesPlants(List<dynamic> rows) async {
    final db = await database;
    int ok = 0, skip = 0, fkMiss = 0;
    await db.transaction((txn) async {
      await txn.delete('diseases_plants');
      for (final item in rows) {
        if (item is! Map) {
          skip++;
          continue;
        }
        final rec = item;
        final diseaseId = _firstNonEmpty(rec, [
          'disease_id',
          'diseaseId',
          'disease_uuid',
          'disease',
        ]);
        final plantId = _firstNonEmpty(rec, [
          'plant_id',
          'plantId',
          'plant_uuid',
          'plant',
        ]);
        if (diseaseId.isEmpty || plantId.isEmpty) {
          print(
            '⏭️ diseases_plants skip: disease="$diseaseId" plant="$plantId" keys=${rec.keys}',
          );
          skip++;
          continue;
        }
        final d = await txn.query(
          'diseases',
          where: 'disease_id=?',
          whereArgs: [diseaseId],
          limit: 1,
        );
        final p = await txn.query(
          'plants',
          where: 'plant_id=?',
          whereArgs: [plantId],
          limit: 1,
        );
        if (d.isEmpty || p.isEmpty) {
          print(
            '⚠️ FK missing diseases_plants: disease="$diseaseId" (${d.isEmpty ? 'missing' : 'ok'}), plant="$plantId" (${p.isEmpty ? 'missing' : 'ok'})',
          );
          fkMiss++;
          continue;
        }
        await txn.insert('diseases_plants', {
          'disease_id': diseaseId,
          'plant_id': plantId,
        });
        ok++;
      }
    });
    print('✅ diseases_plants inserted=$ok, skipped=$skip, fkMissing=$fkMiss');
  }

  Future<void> syncDiseaseRemedy(List<dynamic> rows) async {
    final db = await database;
    int ok = 0, skip = 0, fkMiss = 0;
    await db.transaction((txn) async {
      await txn.delete('disease_remedy');
      for (final item in rows) {
        if (item is! Map) {
          skip++;
          continue;
        }
        final rec = item;
        final diseaseId = _firstNonEmpty(rec, [
          'disease_id',
          'diseaseId',
          'disease_uuid',
          'disease',
        ]);
        final remedyId = _firstNonEmpty(rec, [
          'remedy_id',
          'remedyId',
          'remedy_uuid',
          'remedy',
        ]);
        if (diseaseId.isEmpty || remedyId.isEmpty) {
          print(
            '⏭️ disease_remedy skip: disease="$diseaseId" remedy="$remedyId" keys=${rec.keys}',
          );
          skip++;
          continue;
        }
        final d = await txn.query(
          'diseases',
          where: 'disease_id=?',
          whereArgs: [diseaseId],
          limit: 1,
        );
        final r = await txn.query(
          'remedies',
          where: 'remedy_id=?',
          whereArgs: [remedyId],
          limit: 1,
        );
        if (d.isEmpty || r.isEmpty) {
          print(
            '⚠️ FK missing disease_remedy: disease="$diseaseId" (${d.isEmpty ? 'missing' : 'ok'}), remedy="$remedyId" (${r.isEmpty ? 'missing' : 'ok'})',
          );
          fkMiss++;
          continue;
        }
        await txn.insert('disease_remedy', {
          'disease_id': diseaseId,
          'remedy_id': remedyId,
        });
        ok++;
      }
    });
    print('✅ disease_remedy inserted=$ok, skipped=$skip, fkMissing=$fkMiss');
  }

  // ================= USER DATA SYNC (upload) =================
  Future<Map<String, dynamic>> syncPendingToServer(String accessToken) async {
    try {
      final pending = await getPendingAnalyses();
      print('🚚 upload pending: ${pending.length}');
      if (pending.isEmpty) {
        return {
          'success': true,
          'message': 'No pending',
          'synced': 0,
          'failed': 0,
        };
      }
      int ok = 0, fail = 0;
      final failed = <String>[];
      for (final a in pending) {
        final res = await _uploadAnalysisToServer(a, accessToken);
        if (res['success'] == true) {
          await markAsUploaded(a['id'], res['serverImageUrl'] as String?);
          print('✅ uploaded analysis ${a['id']}');
          ok++;
        } else {
          print('❌ upload failed ${a['id']}');
          fail++;
          failed.add(a['id']);
        }
      }
      return {
        'success': fail == 0,
        'synced': ok,
        'failed': fail,
        'failedIds': failed,
      };
    } catch (e) {
      print('❌ upload sync error: $e');
      return {
        'success': false,
        'message': 'Sync failed: $e',
        'synced': 0,
        'failed': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _uploadAnalysisToServer(
    Map<String, dynamic> analysis,
    String accessToken,
  ) async {
    try {
      final path = analysis['local_path'] as String?;
      if (path == null || !File(path).existsSync()) return {'success': false};

      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/disease/analysis/sync'),
      );
      req.headers['Authorization'] = 'Bearer $accessToken';
      req.files.add(await http.MultipartFile.fromPath('image', path));
      req.fields.addAll({
        'analysisId': analysis['id'].toString(),
        'userId': analysis['user_id'].toString(),
        'cropId': analysis['crop_id'].toString(),
        'imageId': analysis['image_id'].toString(),
        'diseaseId': analysis['disease_id'].toString(),
        'remedyId': analysis['remedy_id'].toString(),
        'confidence': analysis['confidence'].toString(),
        'createdAt': analysis['created_at'].toString(),
      });

      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        String? serverUrl;
        try {
          final body = jsonDecode(resp.body);
          serverUrl =
              (body['server_image_url'] ?? body['imageUrl'] ?? body['url'])
                  ?.toString();
        } catch (_) {}
        return {'success': true, 'serverImageUrl': serverUrl};
      }
      return {'success': false};
    } catch (_) {
      return {'success': false};
    }
  }

  // ================= USER DATA SYNC (down) =================
  Future<Map<String, dynamic>> syncAnalysesFromServer(
    String accessToken, {
    String? since,
  }) async {
    try {
      final uri = since == null
          ? Uri.parse('$baseUrl/disease/analysis/changes')
          : Uri.parse('$baseUrl/disease/analysis/changes?since=$since');
      print('🔽 down-sync analyses: $uri');
      final r = await http
          .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
          .timeout(const Duration(seconds: 15));
      print('📡 analyses ${r.statusCode}, ${r.bodyBytes.length} bytes');
      if (r.statusCode != 200) {
        return {'success': false, 'upserts': 0, 'deleted': 0};
      }

      final payload = jsonDecode(r.body);
      final List<dynamic> rows = payload is List
          ? payload
          : (payload['data'] is List ? payload['data'] : <dynamic>[]);
      final List<dynamic> deletedIds =
          payload is Map && payload['deletedIds'] is List
          ? payload['deletedIds']
          : <dynamic>[];
      print('🧾 analyses rows=${rows.length}, deletedIds=${deletedIds.length}');

      final db = await database;
      int upserts = 0, deletes = 0;
      await db.transaction((txn) async {
        for (final item in rows) {
          if (item is! Map) continue;

          if (item['image_id'] != null) {
            final imgId = item['image_id'].toString();
            final exists = await txn.query(
              'images',
              where: 'image_id=?',
              whereArgs: [imgId],
              limit: 1,
            );
            if (exists.isEmpty) {
              await txn.insert('images', {
                'image_id': imgId,
                'local_path': item['local_path']?.toString() ?? '',
                'server_image_url': item['server_image_url']?.toString(),
                'is_uploaded': 1,
                'created_at': item['created_at']?.toString(),
              });
              print('🖼️ created image $imgId');
            } else {
              await txn.update(
                'images',
                {
                  'server_image_url': item['server_image_url']?.toString(),
                  'is_uploaded': 1,
                },
                where: 'image_id=?',
                whereArgs: [imgId],
              );
            }
          }

          final row = {
            'id': item['id'].toString(),
            'user_id': item['user_id'].toString(),
            'crop_id': item['crop_id'].toString(),
            'image_id': item['image_id'].toString(),
            'disease_id': item['disease_id'].toString(),
            'remedy_id': item['remedy_id'].toString(),
            'confidence': (item['confidence'] as num?)?.toDouble(),
            'created_at': item['created_at']?.toString(),
            'is_uploaded': 1,
            'is_dirty': 0,
          };
          await _upsert(txn, 'disease_analysis_results', row, 'id');
          upserts++;
        }

        for (final did in deletedIds) {
          final id = did.toString();
          final n = await txn.delete(
            'disease_analysis_results',
            where: 'id = ?',
            whereArgs: [id],
          );
          if (n > 0) {
            deletes++;
            print('🗑️ deleted analysis $id');
          }
        }

        final removed = await txn.delete(
          'images',
          where:
              'image_id NOT IN (SELECT image_id FROM disease_analysis_results)',
        );
        if (removed > 0) print('🧹 removed orphan images: $removed');
      });

      print('✅ down-sync done: upserts=$upserts, deletes=$deletes');
      return {'success': true, 'upserts': upserts, 'deleted': deletes};
    } catch (e) {
      print('❌ analyses down-sync error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'upserts': 0,
        'deleted': 0,
      };
    }
  }

  // ================= UTILS =================
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
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
  // At the bottom of lib/src/db/database_helper.dart (inside class DatabaseHelper)

  Future<String?> findPlantIdByName(String plantName) async {
    final db = await database;
    final rows = await db.query(
      'plants',
      columns: ['plant_id'], // snake_case to match CREATE TABLE
      where: 'LOWER(plant_name) = LOWER(?)', // snake_case
      whereArgs: [plantName.trim()],
      limit: 1,
    );
    return rows.isNotEmpty
        ? rows.first['plant_id'] as String
        : null; // snake_case
  }

  Future<String?> findActiveUserCropIdByPlantId({
    required String userId,
    required String plantId,
  }) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
    SELECT uc.user_crop_id
    FROM user_crops uc
    JOIN farms f ON uc.farm_id = f.farm_id
    WHERE f.user_id = ? AND uc.plant_id = ? AND uc.is_active = 1
    ORDER BY uc.planting_date DESC
    LIMIT 1
  ''',
      [userId, plantId],
    );
    return rows.isNotEmpty ? rows.first['user_crop_id'] as String : null;
  }

  Future<String> saveDetectionUsingCatalogByPlantName({
    required String userId,
    required String plantName,
    required String detectedLabel,
    required double confidence,
    required String localImagePath,
  }) async {
    final plantId = await findPlantIdByName(plantName);
    if (plantId == null) throw StateError('Unknown plant name: $plantName');

    final cropId = await findActiveUserCropIdByPlantId(
      userId: userId,
      plantId: plantId,
    );
    if (cropId == null) throw StateError('No active crop found for $plantName');

    return await saveDetectionUsingCatalog(
      userId: userId,
      cropId: cropId,
      detectedLabel: detectedLabel,
      confidence: confidence,
      localImagePath: localImagePath,
    );
  }
}
