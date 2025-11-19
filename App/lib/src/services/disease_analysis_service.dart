// lib/src/services/disease_analysis_service.dart
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

/// Service for managing disease analysis operations
/// Separated from DatabaseHelper for better code organization
class DiseaseAnalysisService {
  static final DiseaseAnalysisService instance = DiseaseAnalysisService._init();
  DiseaseAnalysisService._init();

  final DatabaseHelper _db = DatabaseHelper.instance;

  // ================= DISEASE ANALYSIS OPERATIONS =================

  /// Save disease detection result using plant name
  /// Returns Map with success status and message
  /// ⭐ FIXED: Now properly saves to database with all necessary data
  Future<Map<String, dynamic>> saveDetectionByPlantName({
    required String userId,
    required String plantName,
    required String detectedLabel,
    required double confidence,
    required String localImagePath,
  }) async {
    try {
      debugPrint('💾 Starting save operation...');
      debugPrint('   User: $userId');
      debugPrint('   Plant: $plantName');
      debugPrint('   Disease: $detectedLabel');
      debugPrint('   Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
      debugPrint('   Image: $localImagePath');

      // Call the database helper method
      final analysisId = await _db.saveDetectionUsingCatalogByPlantName(
        userId: userId,
        plantName: plantName,
        detectedLabel: detectedLabel,
        confidence: confidence,
        localImagePath: localImagePath,
      );

      debugPrint('✅ Analysis saved locally with ID: $analysisId');

      return {
        'success': true,
        'analysisId': analysisId,
        'message': 'Analysis saved successfully',
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving detection: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to save detection',
      };
    }
  }

  /// Save disease detection result using plant ID
  /// Returns Map with success status and message
  Future<Map<String, dynamic>> saveDetectionByPlantId({
    required String userId,
    required String plantId,
    required String detectedLabel,
    required double confidence,
    required String localImagePath,
  }) async {
    try {
      debugPrint('💾 Saving detection with plant ID...');

      final analysisId = await _db.saveDetectionUsingCatalog(
        userId: userId,
        plantId: plantId,
        detectedLabel: detectedLabel,
        confidence: confidence,
        localImagePath: localImagePath,
      );

      debugPrint('✅ Analysis saved locally with ID: $analysisId');

      return {
        'success': true,
        'analysisId': analysisId,
        'message': 'Analysis saved successfully',
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving detection: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to save detection',
      };
    }
  }

  /// Get all analyses for a user
  Future<List<Map<String, dynamic>>> getUserAnalyses(String userId) async {
    try {
      final analyses = await _db.getUserAnalyses(userId);
      debugPrint('📊 Found ${analyses.length} analyses for user $userId');
      return analyses;
    } catch (e) {
      debugPrint('❌ Error getting user analyses: $e');
      return [];
    }
  }

  /// Get single analysis by ID
  Future<Map<String, dynamic>?> getAnalysisById(String analysisId) async {
    try {
      return await _db.getAnalysisById(analysisId);
    } catch (e) {
      debugPrint('❌ Error getting analysis by ID: $e');
      return null;
    }
  }

  /// Get pending analyses (not yet uploaded)
  Future<List<Map<String, dynamic>>> getPendingAnalyses() async {
    try {
      final pending = await _db.getPendingAnalyses();
      debugPrint('📤 Found ${pending.length} pending analyses');
      return pending;
    } catch (e) {
      debugPrint('❌ Error getting pending analyses: $e');
      return [];
    }
  }

  /// Find disease ID by label
  Future<String?> findDiseaseIdByLabel(String label) async {
    try {
      return await _db.findDiseaseIdByLabel(label);
    } catch (e) {
      debugPrint('❌ Error finding disease ID: $e');
      return null;
    }
  }

  /// Find plant ID by name
  Future<String?> findPlantIdByName(String plantName) async {
    try {
      return await _db.findPlantIdByName(plantName);
    } catch (e) {
      debugPrint('❌ Error finding plant ID: $e');
      return null;
    }
  }

  /// Insert image record
  Future<String> insertImage({
    required String localPath,
    String? plantId,
  }) async {
    try {
      return await _db.insertImage(localPath: localPath, plantId: plantId);
    } catch (e) {
      debugPrint('❌ Error inserting image: $e');
      rethrow;
    }
  }

  /// Insert disease analysis record
  Future<String> insertDiseaseAnalysis({
    required String userId,
    required String plantId,
    required String imageId,
    required String diseaseId,
    required double confidence,
  }) async {
    try {
      return await _db.insertDiseaseAnalysis(
        userId: userId,
        plantId: plantId,
        imageId: imageId,
        diseaseId: diseaseId,
        confidence: confidence,
      );
    } catch (e) {
      debugPrint('❌ Error inserting disease analysis: $e');
      rethrow;
    }
  }

  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      return await _db.getSyncStatus();
    } catch (e) {
      debugPrint('❌ Error getting sync status: $e');
      return {
        'pending_analyses': 0,
        'pending_images': 0,
        'total_analyses': 0,
        'total_images': 0,
      };
    }
  }

  /// Mark analysis as uploaded
  Future<void> markAsUploaded(String analysisId, String? serverImageUrl) async {
    try {
      await _db.markAsUploaded(analysisId, serverImageUrl);
      debugPrint('✅ Marked analysis $analysisId as uploaded');
    } catch (e) {
      debugPrint('❌ Error marking as uploaded: $e');
    }
  }

  /// Get count of unsynced analyses
  Future<int> getUnsyncedCount() async {
    try {
      final pending = await getPendingAnalyses();
      return pending.length;
    } catch (e) {
      debugPrint('❌ Error getting unsynced count: $e');
      return 0;
    }
  }

  /// Get recent analyses (last N results)
  Future<List<Map<String, dynamic>>> getRecentAnalyses(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final db = await _db.database;
      final results = await db.rawQuery('''
        SELECT dar.*, i.local_path, i.server_image_url, 
               p.common_name as plant_name, d.disease_name
        FROM disease_analysis_results dar
        LEFT JOIN images i ON dar.image_id = i.image_id
        LEFT JOIN plants p ON dar.plant_id = p.plant_id
        LEFT JOIN diseases d ON dar.disease_id = d.disease_id
        WHERE dar.user_id = ?
        ORDER BY dar.created_at DESC
        LIMIT ?
      ''', [userId, limit]);

      return results;
    } catch (e) {
      debugPrint('❌ Error getting recent analyses: $e');
      return [];
    }
  }

  /// Get analyses by plant name
  Future<List<Map<String, dynamic>>> getAnalysesByPlant(
    String userId,
    String plantName,
  ) async {
    try {
      final db = await _db.database;
      final results = await db.rawQuery('''
        SELECT dar.*, i.local_path, i.server_image_url, 
               p.common_name as plant_name, d.disease_name
        FROM disease_analysis_results dar
        LEFT JOIN images i ON dar.image_id = i.image_id
        LEFT JOIN plants p ON dar.plant_id = p.plant_id
        LEFT JOIN diseases d ON dar.disease_id = d.disease_id
        WHERE dar.user_id = ? AND p.common_name = ?
        ORDER BY dar.created_at DESC
      ''', [userId, plantName]);

      return results;
    } catch (e) {
      debugPrint('❌ Error getting analyses by plant: $e');
      return [];
    }
  }

  /// Delete a specific analysis
  Future<bool> deleteAnalysis(String analysisId) async {
    try {
      final db = await _db.database;
      await db.delete(
        'disease_analysis_results',
        where: 'id = ?',
        whereArgs: [analysisId],
      );

      debugPrint('🗑️ Deleted analysis $analysisId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting analysis: $e');
      return false;
    }
  }
}
