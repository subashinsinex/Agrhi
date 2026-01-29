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
}
