// lib/src/database/database_helper.dart
import 'package:path_provider/path_provider.dart';
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
      CREATE TABLE croptypes (
        croptypeid TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE plants (
        plantid TEXT PRIMARY KEY,
        plantname TEXT NOT NULL,
        croptypeid TEXT NOT NULL,
        waterrequirement TEXT NOT NULL,
        FOREIGN KEY (croptypeid) REFERENCES croptypes(croptypeid)
      )
    ''');

    await db.execute('''
      CREATE TABLE soiltypes (
        soiltypeid TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE watersrc (
        watersrcid TEXT PRIMARY KEY,
        source TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE irrigationmethod (
        irrigationid TEXT PRIMARY KEY,
        methodname TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE farms (
        farmid TEXT PRIMARY KEY,
        farmsize REAL NOT NULL,
        surveynumber TEXT NOT NULL UNIQUE,
        createdat TEXT,
        isuploaded INTEGER DEFAULT 0,
        isdirty INTEGER DEFAULT 1,
        isdeleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE farm_soiltypes (
        farm_id TEXT NOT NULL,
        soil_type_id TEXT NOT NULL,
        PRIMARY KEY (farm_id, soil_type_id),
        FOREIGN KEY (farm_id) REFERENCES farms(farmid) ON DELETE CASCADE,
        FOREIGN KEY (soil_type_id) REFERENCES soiltypes(soiltypeid) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE farm_irrigations (
        farm_id TEXT NOT NULL,
        irrigation_id TEXT NOT NULL,
        PRIMARY KEY (farm_id, irrigation_id),
        FOREIGN KEY (farm_id) REFERENCES farms(farmid) ON DELETE CASCADE,
        FOREIGN KEY (irrigation_id) REFERENCES irrigationmethod(irrigationid) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE farm_watersources (
        farm_id TEXT NOT NULL,
        water_src_id TEXT NOT NULL,
        PRIMARY KEY (farm_id, water_src_id),
        FOREIGN KEY (farm_id) REFERENCES farms(farmid) ON DELETE CASCADE,
        FOREIGN KEY (water_src_id) REFERENCES watersrc(watersrcid) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE usercrops (
        usercropid TEXT PRIMARY KEY,
        farmid TEXT NOT NULL,
        plantid TEXT NOT NULL,
        plantingdate TEXT NOT NULL,
        harvestdate TEXT,
        fieldsize REAL,
        soiltypeid TEXT NOT NULL,
        status TEXT CHECK (status IN ('Growing', 'Harvested', 'Planted')),
        isactive INTEGER DEFAULT 1,
        createdat TEXT,
        isuploaded INTEGER DEFAULT 0,
        isdirty INTEGER DEFAULT 1,
        isdeleted INTEGER DEFAULT 0,
        FOREIGN KEY (farmid) REFERENCES farms(farmid) ON DELETE CASCADE,
        FOREIGN KEY (plantid) REFERENCES plants(plantid) ON DELETE RESTRICT,
        FOREIGN KEY (soiltypeid) REFERENCES soiltypes(soiltypeid) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE cropreminders (
        cropid TEXT PRIMARY KEY,
        plantname TEXT NOT NULL,
        harvestreminderdate TEXT,
        notificationids TEXT,
        createdat TEXT,
        FOREIGN KEY (cropid) REFERENCES usercrops(usercropid) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE diseases (
        diseaseid TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        severity TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE diseasesplants (
        diseaseid TEXT NOT NULL,
        plantid TEXT NOT NULL,
        PRIMARY KEY (diseaseid, plantid),
        FOREIGN KEY (diseaseid) REFERENCES diseases(diseaseid),
        FOREIGN KEY (plantid) REFERENCES plants(plantid)
      )
    ''');

    await db.execute('''
      CREATE TABLE remedies (
        remedyid TEXT PRIMARY KEY,
        remedy TEXT NOT NULL,
        prevention TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE diseaseremedies (
        diseaseid TEXT NOT NULL,
        remedyid TEXT NOT NULL,
        PRIMARY KEY (diseaseid, remedyid),
        FOREIGN KEY (diseaseid) REFERENCES diseases(diseaseid),
        FOREIGN KEY (remedyid) REFERENCES remedies(remedyid)
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
        plant_id TEXT NOT NULL,
        image_id TEXT NOT NULL,
        disease_id TEXT NOT NULL,
        confidence REAL,
        created_at TEXT,
        is_uploaded INTEGER DEFAULT 0,
        is_dirty INTEGER DEFAULT 1,
        FOREIGN KEY (plant_id) REFERENCES plants(plantid),
        FOREIGN KEY (image_id) REFERENCES images(image_id),
        FOREIGN KEY (disease_id) REFERENCES diseases(diseaseid)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS subsidies_cache (
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        category TEXT,
        amount TEXT,
        link TEXT,
        cached_at TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_farms_pending ON farms(isdirty, isuploaded)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_farms_deleted ON farms(isdeleted)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_farms_survey ON farms(surveynumber)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_farms_date ON farms(createdat)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_crops_pending ON usercrops(isdirty, isuploaded)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_crops_deleted ON usercrops(isdeleted)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_crops_farm ON usercrops(farmid)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_crops_active ON usercrops(isactive)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_crops_date ON usercrops(createdat)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cropreminders_harvest ON cropreminders(harvestreminderdate)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dar_pending ON disease_analysis_results(is_dirty, is_uploaded)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_dar_user ON disease_analysis_results(user_id)',
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

    print('✅ DB created with final schema');
  }

  // ==================== REMINDER METHODS ====================

  Future<void> upsertCropReminder({
    required String cropId,
    required String plantName,
    DateTime? harvestReminderDate,
    required String notificationIds,
  }) async {
    final db = await database;

    await db.insert('cropreminders', {
      'cropid': cropId,
      'plantname': plantName,
      'harvestreminderdate': harvestReminderDate?.toIso8601String(),
      'notificationids': notificationIds,
      'createdat': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCropReminder(String cropId) async {
    final db = await database;
    await db.delete('cropreminders', where: 'cropid = ?', whereArgs: [cropId]);
  }

  Future<Map<String, dynamic>?> getCropReminder(String cropId) async {
    final db = await database;
    final rows = await db.query(
      'cropreminders',
      where: 'cropid = ?',
      whereArgs: [cropId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllActiveCropReminders() async {
    final db = await database;

    return await db.rawQuery('''
      SELECT
        cr.cropid,
        cr.plantname,
        cr.harvestreminderdate,
        cr.notificationids,
        uc.isactive,
        uc.isdeleted
      FROM cropreminders cr
      INNER JOIN usercrops uc
        ON uc.usercropid = cr.cropid
      WHERE uc.isactive = 1
        AND uc.isdeleted = 0
      ORDER BY cr.createdat DESC
    ''');
  }

  Future<int> getActiveCropRemindersCount() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM cropreminders cr
      INNER JOIN usercrops uc
        ON uc.usercropid = cr.cropid
      WHERE uc.isactive = 1
        AND uc.isdeleted = 0
    ''');

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getUpcomingReminders({
    int daysAhead = 7,
  }) async {
    final db = await database;

    final now = DateTime.now();
    final end = now.add(Duration(days: daysAhead));

    return await db.rawQuery(
      '''
      SELECT
        cr.cropid,
        cr.plantname,
        cr.harvestreminderdate,
        'harvest' AS remindertype,
        NULL AS daysuntilfollowup,
        CAST(julianday(cr.harvestreminderdate) - julianday(?) AS INTEGER) AS daysuntilharvest,
        cr.harvestreminderdate AS sortdate
      FROM cropreminders cr
      INNER JOIN usercrops uc
        ON uc.usercropid = cr.cropid
      WHERE uc.isactive = 1
        AND uc.isdeleted = 0
        AND cr.harvestreminderdate IS NOT NULL
        AND datetime(cr.harvestreminderdate) >= datetime(?)
        AND datetime(cr.harvestreminderdate) <= datetime(?)
      ORDER BY datetime(sortdate) ASC
    ''',
      [now.toIso8601String(), now.toIso8601String(), end.toIso8601String()],
    );
  }

  // ==================== SOFT DELETE METHODS ====================

  Future<Map<String, dynamic>> markFarmAsDeleted(String farmId) async {
    final db = await database;

    return await db.transaction((txn) async {
      final farmRows = await txn.query(
        'farms',
        where: 'farmid = ? AND isdeleted = 0',
        whereArgs: [farmId],
        limit: 1,
      );

      if (farmRows.isEmpty) {
        return {
          'success': false,
          'message': 'Farm not found or already deleted',
        };
      }

      final farm = farmRows.first;
      final wasUploaded = farm['isuploaded'] == 1;

      final activeCrops = await txn.query(
        'usercrops',
        where: 'farmid = ? AND isdeleted = 0',
        whereArgs: [farmId],
      );

      if (activeCrops.isNotEmpty) {
        return {
          'success': false,
          'message':
              'Cannot delete farm with ${activeCrops.length} active crop(s)',
          'cropCount': activeCrops.length,
        };
      }

      if (wasUploaded) {
        await txn.update(
          'farms',
          {'isdeleted': 1, 'isdirty': 1},
          where: 'farmid = ?',
          whereArgs: [farmId],
        );

        print('✅ Farm marked as deleted (will sync): $farmId');

        return {
          'success': true,
          'message': 'Farm marked for deletion',
          'type': 'soft_delete',
          'farmId': farmId,
        };
      } else {
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

        await txn.delete('farms', where: 'farmid = ?', whereArgs: [farmId]);

        print('✅ Farm hard deleted (local only): $farmId');

        return {
          'success': true,
          'message': 'Farm deleted',
          'type': 'hard_delete',
          'farmId': farmId,
        };
      }
    });
  }

  Future<Map<String, dynamic>> markCropAsDeleted(String cropId) async {
    final db = await database;

    return await db.transaction((txn) async {
      final cropRows = await txn.query(
        'usercrops',
        where: 'usercropid = ? AND isdeleted = 0',
        whereArgs: [cropId],
        limit: 1,
      );

      if (cropRows.isEmpty) {
        return {
          'success': false,
          'message': 'Crop not found or already deleted',
        };
      }

      final crop = cropRows.first;
      final wasUploaded = crop['isuploaded'] == 1;

      if (wasUploaded) {
        await txn.update(
          'usercrops',
          {'isdeleted': 1, 'isdirty': 1},
          where: 'usercropid = ?',
          whereArgs: [cropId],
        );

        print('✅ Crop marked as deleted (will sync): $cropId');

        return {
          'success': true,
          'message': 'Crop marked for deletion',
          'type': 'soft_delete',
          'cropId': cropId,
        };
      } else {
        await txn.delete(
          'usercrops',
          where: 'usercropid = ?',
          whereArgs: [cropId],
        );

        print('✅ Crop hard deleted (local only): $cropId');

        return {
          'success': true,
          'message': 'Crop deleted',
          'type': 'hard_delete',
          'cropId': cropId,
        };
      }
    });
  }

  Future<List<Map<String, dynamic>>> getPendingFarmDeletions() async {
    final db = await database;
    return await db.query('farms', where: 'isdeleted = 1 AND isdirty = 1');
  }

  Future<List<Map<String, dynamic>>> getPendingCropDeletions() async {
    final db = await database;
    return await db.query('usercrops', where: 'isdeleted = 1 AND isdirty = 1');
  }

  Future<void> cleanupDeletedFarm(String farmId) async {
    final db = await database;

    await db.transaction((txn) async {
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
      await txn.delete('farms', where: 'farmid = ?', whereArgs: [farmId]);
    });

    print('✅ Cleaned up deleted farm: $farmId');
  }

  Future<void> cleanupDeletedCrop(String cropId) async {
    final db = await database;
    await db.delete('usercrops', where: 'usercropid = ?', whereArgs: [cropId]);
    print('✅ Cleaned up deleted crop: $cropId');
  }

  // ==================== JUNCTION TABLE METHODS ====================

  Future<String> upsertFarmWithRelations({
    required double farmSize,
    required String surveyNumber,
    required List<String> soilTypeIds,
    required List<String> irrigationIds,
    required List<String> waterSrcIds,
    String? farmId,
  }) async {
    final db = await database;

    final id = farmId ?? const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      final existingFarm = await txn.query(
        'farms',
        where: 'farmid = ?',
        whereArgs: [id],
        limit: 1,
      );

      final isUpdate = existingFarm.isNotEmpty;
      final wasUploaded = isUpdate
          ? (existingFarm.first['isuploaded'] == 1)
          : false;

      final farmData = {
        'farmid': id,
        'farmsize': farmSize,
        'surveynumber': surveyNumber,
        'createdat': isUpdate ? existingFarm.first['createdat'] : now,
        'isuploaded': wasUploaded ? 1 : 0,
        'isdirty': 1,
        'isdeleted': 0,
      };

      if (isUpdate) {
        await txn.update(
          'farms',
          farmData,
          where: 'farmid = ?',
          whereArgs: [id],
        );
      } else {
        await txn.insert('farms', farmData);
      }

      await txn.delete('farm_soiltypes', where: 'farm_id = ?', whereArgs: [id]);
      await txn.delete(
        'farm_irrigations',
        where: 'farm_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'farm_watersources',
        where: 'farm_id = ?',
        whereArgs: [id],
      );

      for (final soilTypeId in soilTypeIds) {
        await txn.insert('farm_soiltypes', {
          'farm_id': id,
          'soil_type_id': soilTypeId,
        });
      }

      for (final irrigationId in irrigationIds) {
        await txn.insert('farm_irrigations', {
          'farm_id': id,
          'irrigation_id': irrigationId,
        });
      }

      for (final waterSrcId in waterSrcIds) {
        await txn.insert('farm_watersources', {
          'farm_id': id,
          'water_src_id': waterSrcId,
        });
      }

      return id;
    });
  }

  Future<List<Map<String, dynamic>>> getAllFarmsWithRelations() async {
    final db = await database;
    final farms = await db.query(
      'farms',
      where: 'isdeleted = 0',
      orderBy: 'createdat DESC',
    );

    List<Map<String, dynamic>> result = [];

    for (var farm in farms) {
      final farmId = farm['farmid'] as String;

      final soilTypes = await db.rawQuery(
        '''
        SELECT st.soiltypeid, st.name
        FROM farm_soiltypes fst
        JOIN soiltypes st ON fst.soil_type_id = st.soiltypeid
        WHERE fst.farm_id = ?
      ''',
        [farmId],
      );

      final irrigations = await db.rawQuery(
        '''
        SELECT im.irrigationid, im.methodname
        FROM farm_irrigations fi
        JOIN irrigationmethod im ON fi.irrigation_id = im.irrigationid
        WHERE fi.farm_id = ?
      ''',
        [farmId],
      );

      final waterSources = await db.rawQuery(
        '''
        SELECT ws.watersrcid, ws.source
        FROM farm_watersources fws
        JOIN watersrc ws ON fws.water_src_id = ws.watersrcid
        WHERE fws.farm_id = ?
      ''',
        [farmId],
      );

      Map<String, dynamic> farmWithRelations = Map.from(farm);
      farmWithRelations['soil_types'] = soilTypes;
      farmWithRelations['irrigations'] = irrigations;
      farmWithRelations['water_sources'] = waterSources;

      result.add(farmWithRelations);
    }

    return result;
  }

  Future<Map<String, dynamic>?> getFarmWithRelations(String farmId) async {
    final db = await database;
    final farms = await db.query(
      'farms',
      where: 'farmid = ?',
      whereArgs: [farmId],
    );
    if (farms.isEmpty) return null;

    final farm = farms.first;

    final soilTypes = await db.rawQuery(
      '''
      SELECT st.soiltypeid, st.name
      FROM farm_soiltypes fst
      JOIN soiltypes st ON fst.soil_type_id = st.soiltypeid
      WHERE fst.farm_id = ?
    ''',
      [farmId],
    );

    final irrigations = await db.rawQuery(
      '''
      SELECT im.irrigationid, im.methodname
      FROM farm_irrigations fi
      JOIN irrigationmethod im ON fi.irrigation_id = im.irrigationid
      WHERE fi.farm_id = ?
    ''',
      [farmId],
    );

    final waterSources = await db.rawQuery(
      '''
      SELECT ws.watersrcid, ws.source
      FROM farm_watersources fws
      JOIN watersrc ws ON fws.water_src_id = ws.watersrcid
      WHERE fws.farm_id = ?
    ''',
      [farmId],
    );

    Map<String, dynamic> farmWithRelations = Map.from(farm);
    farmWithRelations['soil_types'] = soilTypes;
    farmWithRelations['irrigations'] = irrigations;
    farmWithRelations['water_sources'] = waterSources;
    farmWithRelations['soil_type_ids'] = soilTypes
        .map((s) => s['soiltypeid'].toString())
        .toList();
    farmWithRelations['irrigation_ids'] = irrigations
        .map((i) => i['irrigationid'].toString())
        .toList();
    farmWithRelations['water_source_ids'] = waterSources
        .map((w) => w['watersrcid'].toString())
        .toList();

    return farmWithRelations;
  }

  // ==================== FARMS DATABASE OPERATIONS ====================

  Future<String> upsertCrop({
    required String farmId,
    required String plantId,
    required String plantingDate,
    String? harvestDate,
    double? duration,
    required double fieldSize,
    required String soilTypeId,
    required String status,
    int isActive = 1,
    String? cropId,
  }) async {
    final db = await database;
    final id = cropId ?? const Uuid().v4();

    await db.insert('usercrops', {
      'usercropid': id,
      'farmid': farmId,
      'plantid': plantId,
      'plantingdate': plantingDate,
      'harvestdate': harvestDate,
      'fieldsize': fieldSize,
      'soiltypeid': soilTypeId,
      'status': status,
      'isactive': isActive,
      'createdat': DateTime.now().toIso8601String(),
      'isuploaded': 0,
      'isdirty': 1,
      'isdeleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return id;
  }

  Future<List<Map<String, dynamic>>> getAllFarms() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT f.*
      FROM farms f
      WHERE f.isdeleted = 0
      ORDER BY f.createdat DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getAllCrops() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        uc.*,
        p.plantname as plant_name,
        ct.name as crop_type,
        f.surveynumber as survey_number,
        st.name as soil_type
      FROM usercrops uc
      LEFT JOIN plants p ON uc.plantid = p.plantid
      LEFT JOIN croptypes ct ON p.croptypeid = ct.croptypeid
      LEFT JOIN farms f ON uc.farmid = f.farmid
      LEFT JOIN soiltypes st ON uc.soiltypeid = st.soiltypeid
      WHERE uc.isdeleted = 0
      ORDER BY uc.createdat DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getPendingFarms() async {
    final db = await database;
    return await db.query(
      'farms',
      where: '(isdirty = 1 OR isuploaded = 0) AND isdeleted = 0',
      orderBy: 'createdat DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingCrops() async {
    final db = await database;
    return await db.query(
      'usercrops',
      where: '(isdirty = 1 OR isuploaded = 0) AND isdeleted = 0',
      orderBy: 'createdat DESC',
    );
  }

  Future<void> markFarmAsUploaded(String farmId) async {
    final db = await database;
    await db.update(
      'farms',
      {'isuploaded': 1, 'isdirty': 0},
      where: 'farmid = ?',
      whereArgs: [farmId],
    );
  }

  Future<void> markCropAsUploaded(String cropId) async {
    final db = await database;
    await db.update(
      'usercrops',
      {'isuploaded': 1, 'isdirty': 0},
      where: 'usercropid = ?',
      whereArgs: [cropId],
    );
  }

  // ==================== HELPER METHODS ====================

  String _s(dynamic v) => (v ?? '').toString().trim();

  String _firstNonEmpty(Map rec, List<String> keys) {
    for (final k in keys) {
      final val = rec[k];
      if (val != null && _s(val).isNotEmpty) return _s(val);
    }
    return '';
  }

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

  // ==================== IMAGE & ANALYSIS OPS ====================

  String _normalizeLabel(String label) => label.replaceAll('_', ' ').trim();

  Future<String?> findDiseaseIdByLabel(String label) async {
    final db = await database;
    final norm = _normalizeLabel(label);
    final rows = await db.query(
      'diseases',
      columns: ['diseaseid'],
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [norm],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first['diseaseid'] as String : null;
  }

  Future<String> saveDetectionUsingCatalog({
    required String userId,
    required String plantId,
    required String detectedLabel,
    required double confidence,
    required String localImagePath,
  }) async {
    final db = await database;
    final diseaseId = await findDiseaseIdByLabel(detectedLabel);

    if (diseaseId == null) {
      throw StateError('Unknown disease label: $detectedLabel');
    }

    final imageId = const Uuid().v4();

    String finalImagePath = localImagePath;
    try {
      final plantRows = await db.query(
        'plants',
        columns: ['plantname'],
        where: 'plantid = ?',
        whereArgs: [plantId],
        limit: 1,
      );
      final plantName = plantRows.isNotEmpty
          ? (plantRows.first['plantname'] as String)
          : 'plant';

      String sanitize(String s) =>
          s.replaceAll(RegExp(r'[^\w]'), '_').toLowerCase();

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/disease_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final newFileName =
          '${sanitize(plantName)}_${sanitize(detectedLabel)}_$imageId.jpg';
      final newPath = '${imagesDir.path}/$newFileName';

      await File(localImagePath).copy(newPath);
      await File(localImagePath).delete();
      finalImagePath = newPath;
    } catch (e) {
      print('⚠️ Image rename failed (using original): $e');
    }

    return await db.transaction((txn) async {
      await txn.insert('images', {
        'image_id': imageId,
        'local_path': finalImagePath,
        'server_image_url': null,
        'is_uploaded': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      final analysisId = const Uuid().v4();
      await txn.insert('disease_analysis_results', {
        'id': analysisId,
        'user_id': userId,
        'plant_id': plantId,
        'image_id': imageId,
        'disease_id': diseaseId,
        'confidence': confidence,
        'created_at': DateTime.now().toIso8601String(),
        'is_uploaded': 0,
        'is_dirty': 1,
      });

      return analysisId;
    });
  }

  // ==================== QUERIES ====================

  Future<List<Map<String, dynamic>>> getPendingAnalyses() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        dar.*,
        d.name as disease_name,
        d.severity,
        i.local_path,
        p.plantname as plant_name,
        GROUP_CONCAT(r.remedy, '|||') as remedies,
        GROUP_CONCAT(r.prevention, '|||') as preventions
      FROM disease_analysis_results dar
      LEFT JOIN diseases d ON dar.disease_id = d.diseaseid
      LEFT JOIN images i ON dar.image_id = i.image_id
      LEFT JOIN plants p ON dar.plant_id = p.plantid
      LEFT JOIN diseaseremedies dr ON d.diseaseid = dr.diseaseid
      LEFT JOIN remedies r ON dr.remedyid = r.remedyid
      WHERE dar.is_dirty = 1 OR dar.is_uploaded = 0
      GROUP BY dar.id
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
        i.local_path,
        i.server_image_url,
        p.plantname as plant_name,
        GROUP_CONCAT(r.remedy, '|||') as remedies,
        GROUP_CONCAT(r.prevention, '|||') as preventions
      FROM disease_analysis_results dar
      LEFT JOIN diseases d ON dar.disease_id = d.diseaseid
      LEFT JOIN images i ON dar.image_id = i.image_id
      LEFT JOIN plants p ON dar.plant_id = p.plantid
      LEFT JOIN diseaseremedies dr ON d.diseaseid = dr.diseaseid
      LEFT JOIN remedies r ON dr.remedyid = r.remedyid
      WHERE dar.user_id = ?
      GROUP BY dar.id
      ORDER BY dar.created_at DESC
    ''',
      [userId],
    );
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

  // ==================== CATALOG SYNC ====================

  Future<List<Map<String, dynamic>>> getReferenceTableVersions() async {
    final db = await database;
    return await db.query('reference_table_versions');
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

  // ==================== CATALOG SYNC METHODS ====================

  Future<void> syncDiseases(List<dynamic> rows) async {
    final mapped = <Map<String, Object?>>[];
    int skip = 0;

    for (final item in rows) {
      if (item is! Map) {
        skip++;
        continue;
      }

      final rec = item;
      final id = _s(rec['diseaseid'] ?? rec['disease_id']);
      final name = _s(rec['name']);

      if (id.isEmpty || name.isEmpty) {
        skip++;
        continue;
      }

      mapped.add({
        'diseaseid': id,
        'name': name,
        'severity': _s(rec['severity']).isEmpty
            ? 'Unknown'
            : _s(rec['severity']),
      });
    }

    await _reconcileSnapshot(table: 'diseases', pk: 'diseaseid', rows: mapped);
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
      final id = _s(rec['remedyid'] ?? rec['remedy_id']);
      final remedy = _s(rec['remedy']);

      if (id.isEmpty || remedy.isEmpty) {
        skip++;
        continue;
      }

      mapped.add({
        'remedyid': id,
        'remedy': remedy,
        'prevention': _s(rec['prevention']),
      });
    }

    await _reconcileSnapshot(table: 'remedies', pk: 'remedyid', rows: mapped);
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
        'plantid',
        'plant_id',
        'id',
        'uuid',
        'plantId',
      ]);
      final plantName = _firstNonEmpty(rec, [
        'plantname',
        'plant_name',
        'name',
        'title',
        'label',
      ]);
      final cropType = _firstNonEmpty(rec, [
        'croptypeid',
        'crop_type_id',
        'cropTypeId',
        'crop_type',
        'cropType',
      ]);
      final waterReq = _firstNonEmpty(rec, [
        'waterrequirement',
        'water_requirement',
        'waterRequirement',
        'water',
        'water_req',
      ]);

      if (plantId.isEmpty || plantName.isEmpty || cropType.isEmpty) {
        skip++;
        continue;
      }

      mapped.add({
        'plantid': plantId,
        'plantname': plantName,
        'croptypeid': cropType,
        'waterrequirement': waterReq.isEmpty ? 'Medium' : waterReq,
      });
    }

    await _reconcileSnapshot(table: 'plants', pk: 'plantid', rows: mapped);
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
      final id = _s(rec['soiltypeid'] ?? rec['soil_type_id']);
      final name = _s(rec['name']);

      if (id.isEmpty || name.isEmpty) {
        skip++;
        continue;
      }

      mapped.add({'soiltypeid': id, 'name': name});
    }

    await _reconcileSnapshot(
      table: 'soiltypes',
      pk: 'soiltypeid',
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
      final id = _s(rec['croptypeid'] ?? rec['crop_type_id']);
      final name = _s(rec['name']);

      if (id.isEmpty || name.isEmpty) {
        skip++;
        continue;
      }

      mapped.add({'croptypeid': id, 'name': name});
    }

    await _reconcileSnapshot(
      table: 'croptypes',
      pk: 'croptypeid',
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
      final id = _s(rec['watersrcid'] ?? rec['water_src_id']);
      final src = _s(rec['source']);

      if (id.isEmpty || src.isEmpty) {
        skip++;
        continue;
      }

      mapped.add({'watersrcid': id, 'source': src});
    }

    await _reconcileSnapshot(table: 'watersrc', pk: 'watersrcid', rows: mapped);
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
      final id = _s(rec['irrigationid'] ?? rec['irrigation_id']);
      final name = _s(rec['methodname'] ?? rec['method_name']);

      if (id.isEmpty || name.isEmpty) {
        skip++;
        continue;
      }

      mapped.add({'irrigationid': id, 'methodname': name});
    }

    await _reconcileSnapshot(
      table: 'irrigationmethod',
      pk: 'irrigationid',
      rows: mapped,
    );

    print(
      '✅ irrigation_method reconcile: kept=${mapped.length}, skipped=$skip',
    );
  }

  Future<void> syncDiseasesPlants(List<dynamic> rows) async {
    final db = await database;

    final diseases = await db.query('diseases', columns: ['diseaseid']);
    final plants = await db.query('plants', columns: ['plantid']);

    final validDiseases = diseases.map((d) => d['diseaseid'] as String).toSet();
    final validPlants = plants.map((p) => p['plantid'] as String).toSet();

    int ok = 0, skip = 0, fkMiss = 0;

    await db.transaction((txn) async {
      await txn.delete('diseasesplants');

      final batch = txn.batch();

      for (final item in rows) {
        if (item is! Map) {
          skip++;
          continue;
        }

        final rec = item;
        final diseaseId = _firstNonEmpty(rec, [
          'diseaseid',
          'disease_id',
          'diseaseId',
          'disease_uuid',
          'disease',
        ]);
        final plantId = _firstNonEmpty(rec, [
          'plantid',
          'plant_id',
          'plantId',
          'plant_uuid',
          'plant',
        ]);

        if (diseaseId.isEmpty || plantId.isEmpty) {
          skip++;
          continue;
        }

        if (!validDiseases.contains(diseaseId) ||
            !validPlants.contains(plantId)) {
          fkMiss++;
          continue;
        }

        batch.insert('diseasesplants', {
          'diseaseid': diseaseId,
          'plantid': plantId,
        });
        ok++;
      }

      await batch.commit(noResult: true);
    });

    print('✅ diseases_plants inserted=$ok, skipped=$skip, fkMissing=$fkMiss');
  }

  Future<void> syncDiseaseRemedy(List<dynamic> rows) async {
    final db = await database;

    final diseases = await db.query('diseases', columns: ['diseaseid']);
    final remedies = await db.query('remedies', columns: ['remedyid']);

    final validDiseases = diseases.map((d) => d['diseaseid'] as String).toSet();
    final validRemedies = remedies.map((r) => r['remedyid'] as String).toSet();

    int ok = 0, skip = 0, fkMiss = 0;

    await db.transaction((txn) async {
      await txn.delete('diseaseremedies');

      final batch = txn.batch();

      for (final item in rows) {
        if (item is! Map) {
          skip++;
          continue;
        }

        final rec = item;
        final diseaseId = _firstNonEmpty(rec, [
          'diseaseid',
          'disease_id',
          'diseaseId',
          'disease_uuid',
          'disease',
        ]);
        final remedyId = _firstNonEmpty(rec, [
          'remedyid',
          'remedy_id',
          'remedyId',
          'remedy_uuid',
          'remedy',
        ]);

        if (diseaseId.isEmpty || remedyId.isEmpty) {
          skip++;
          continue;
        }

        if (!validDiseases.contains(diseaseId) ||
            !validRemedies.contains(remedyId)) {
          fkMiss++;
          continue;
        }

        batch.insert('diseaseremedies', {
          'diseaseid': diseaseId,
          'remedyid': remedyId,
        });
        ok++;
      }

      await batch.commit(noResult: true);
    });

    print('✅ disease_remedy inserted=$ok, skipped=$skip, fkMissing=$fkMiss');
  }

  // ==================== USER DATA SYNC ====================

  Future<Map<String, dynamic>> _uploadAnalysisToServer(
    Map<String, dynamic> analysis,
    String accessToken,
  ) async {
    try {
      final path = analysis['local_path'] as String?;
      if (path == null || !File(path).existsSync()) {
        return {'success': false};
      }

      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/disease/analysis/sync'),
      );

      req.headers['Authorization'] = 'Bearer $accessToken';
      req.files.add(await http.MultipartFile.fromPath('image', path));
      req.fields.addAll({
        'analysisId': analysis['id'].toString(),
        'userId': analysis['user_id'].toString(),
        'plantId': analysis['plant_id'].toString(),
        'imageId': analysis['image_id'].toString(),
        'diseaseId': analysis['disease_id'].toString(),
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

  // ==================== UTILITIES ====================

  Future<Map<String, dynamic>> getSyncStatus() async {
    final pending = await getPendingAnalyses();
    final pendingFarms = await getPendingFarms();
    final pendingCrops = await getPendingCrops();
    final stats = await getDatabaseStats();

    return {
      'pendingCount': pending.length,
      'pendingFarms': pendingFarms.length,
      'pendingCrops': pendingCrops.length,
      'totalAnalyses': stats['analyses'],
      'totalImages': stats['images'],
      'totalFarms': stats['farms'],
      'totalCrops': stats['crops'],
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
            'SELECT COUNT(*) FROM usercrops WHERE isactive = 1 AND isdeleted = 0',
          ),
        ) ??
        0;

    final farmsCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM farms WHERE isdeleted = 0'),
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
      'farms': farmsCount,
      'diseases': diseasesCount,
    };
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<String?> findPlantIdByName(String plantName) async {
    final db = await database;
    final rows = await db.query(
      'plants',
      columns: ['plantid'],
      where: 'LOWER(plantname) = LOWER(?)',
      whereArgs: [plantName.trim()],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first['plantid'] as String : null;
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

    return await saveDetectionUsingCatalog(
      userId: userId,
      plantId: plantId,
      detectedLabel: detectedLabel,
      confidence: confidence,
      localImagePath: localImagePath,
    );
  }

  Future<List<Map<String, dynamic>>> getAllSoilTypes() async {
    final db = await database;
    return await db.query('soiltypes');
  }

  Future<List<Map<String, dynamic>>> getAllIrrigationTypes() async {
    final db = await database;
    return await db.query('irrigationmethod');
  }

  Future<List<Map<String, dynamic>>> getAllWaterSources() async {
    final db = await database;
    return await db.query('watersrc');
  }

  Future<List<Map<String, dynamic>>> getAllPlants() async {
    final db = await database;
    return await db.query('plants');
  }

  Future<List<Map<String, dynamic>>> getCropsByFarmId(String farmId) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT
        uc.*,
        p.plantname as plantname,
        ct.name as croptype,
        st.name as soiltype
      FROM usercrops uc
      LEFT JOIN plants p ON uc.plantid = p.plantid
      LEFT JOIN croptypes ct ON p.croptypeid = ct.croptypeid
      LEFT JOIN soiltypes st ON uc.soiltypeid = st.soiltypeid
      WHERE uc.farmid = ? AND uc.isdeleted = 0
      ORDER BY uc.createdat DESC
      ''',
      [farmId],
    );
  }

  Future<void> updateCropActiveStatus({
    required String cropId,
    required int isActive,
  }) async {
    final db = await database;

    await db.update(
      'usercrops',
      {'isactive': isActive, 'isdirty': 1},
      where: 'usercropid = ?',
      whereArgs: [cropId],
    );
  }

  Future<void> cacheSubsidies(List<Map<String, dynamic>> subsidies) async {
    final db = await database;
    await db.delete('subsidies_cache');

    for (final subsidy in subsidies) {
      await db.insert('subsidies_cache', {
        ...subsidy,
        'cached_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Map<String, dynamic>>> getCachedSubsidies() async {
    final db = await database;
    return await db.query('subsidies_cache', orderBy: 'title ASC');
  }
}
