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
  Future<Map<String, dynamic>> saveDetectionByPlantName({
    required String userId,
    required String plantName,
    required String detectedLabel,
    required double confidence,
    required String localImagePath,
  }) async {
    try {
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
    } catch (e) {
      debugPrint('❌ Error saving detection: $e');
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
    } catch (e) {
      debugPrint('❌ Error saving detection: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to save detection',
      };
    }
  }

  /// Get all analyses for a user
  Future<List<Map<String, dynamic>>> getUserAnalyses(String userId) async {
    return await _db.getUserAnalyses(userId);
  }

  /// Get single analysis by ID
  Future<Map<String, dynamic>?> getAnalysisById(String analysisId) async {
    return await _db.getAnalysisById(analysisId);
  }

  /// Get pending analyses (not yet uploaded)
  Future<List<Map<String, dynamic>>> getPendingAnalyses() async {
    return await _db.getPendingAnalyses();
  }

  /// Find disease ID by label
  Future<String?> findDiseaseIdByLabel(String label) async {
    return await _db.findDiseaseIdByLabel(label);
  }

  /// Find plant ID by name
  Future<String?> findPlantIdByName(String plantName) async {
    return await _db.findPlantIdByName(plantName);
  }

  /// Insert image record
  Future<String> insertImage({
    required String localPath,
    String? plantId,
  }) async {
    return await _db.insertImage(localPath: localPath, plantId: plantId);
  }

  /// Insert disease analysis record
  Future<String> insertDiseaseAnalysis({
    required String userId,
    required String plantId,
    required String imageId,
    required String diseaseId,
    required double confidence,
  }) async {
    return await _db.insertDiseaseAnalysis(
      userId: userId,
      plantId: plantId,
      imageId: imageId,
      diseaseId: diseaseId,
      confidence: confidence,
    );
  }

  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    return await _db.getSyncStatus();
  }

  /// Mark analysis as uploaded
  Future<void> markAsUploaded(String analysisId, String? serverImageUrl) async {
    await _db.markAsUploaded(analysisId, serverImageUrl);
  }
}
