import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/constants.dart';

class ModelDownloadService {
  static final ModelDownloadService instance = ModelDownloadService._();
  ModelDownloadService._();

  // Remove '/api' from base URL to get server root
  static final String serverUrl = AppConstants.baseUrl.replaceAll('/api', '');

  final _dio = Dio();

  // Define your model information with actual file sizes from your server
  static final Map<String, ModelInfo> modelInfo = {
    'Banana': ModelInfo(
      url: '$serverUrl/models/banana_model.tflite',
      size: 12.76, // 13,070 KB ≈ 12.76 MB
      fileName: 'banana_model.tflite',
    ),
    'Coconut': ModelInfo(
      url: '$serverUrl/models/coconut_model.tflite',
      size: 32.08, // 32,851 KB ≈ 32.08 MB
      fileName: 'coconut_model.tflite',
    ),
    'Coffee': ModelInfo(
      url: '$serverUrl/models/coffee_model.tflite',
      size: 2.63, // 2,691 KB ≈ 2.63 MB
      fileName: 'coffee_model.tflite',
    ),
    'Corn': ModelInfo(
      url: '$serverUrl/models/corn_model.tflite',
      size: 42.62, // 43,639 KB ≈ 42.62 MB
      fileName: 'corn_model.tflite',
    ),
    'Cotton': ModelInfo(
      url: '$serverUrl/models/cotton_model.tflite',
      size: 32.08, // 32,850 KB ≈ 32.08 MB
      fileName: 'cotton_model.tflite',
    ),
    'Groundnut': ModelInfo(
      url: '$serverUrl/models/groundnut_model.tflite',
      size: 2.63, // 2,692 KB ≈ 2.63 MB
      fileName: 'groundnut_model.tflite',
    ),
    'Rice': ModelInfo(
      url: '$serverUrl/models/rice_model.tflite',
      size: 12.71, // 13,018 KB ≈ 12.71 MB
      fileName: 'rice_model.tflite',
    ),
    'Sugarcane': ModelInfo(
      url: '$serverUrl/models/sugarcane_model.tflite',
      size: 9.14, // 9,360 KB ≈ 9.14 MB
      fileName: 'sugarcane_model.tflite',
    ),
    'Tomato': ModelInfo(
      url: '$serverUrl/models/tomato_model.tflite',
      size: 12.77, // 13,075 KB ≈ 12.77 MB
      fileName: 'tomato_model.tflite',
    ),
    'Wheat': ModelInfo(
      url: '$serverUrl/models/wheat_model.tflite',
      size: 2.63, // 2,691 KB ≈ 2.63 MB
      fileName: 'wheat_model.tflite',
    ),
  };

  // Make this public so provider can access it
  Future<String> getModelFilePath(String cropName) async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    final info = modelInfo[cropName];
    if (info == null) throw Exception('Model info not found for: $cropName');
    return '${modelDir.path}/${info.fileName}';
  }

  Future<bool> isModelDownloaded(String cropName) async {
    try {
      final filePath = await getModelFilePath(cropName);
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  Future<void> downloadModel(
    String cropName, {
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    final info = modelInfo[cropName];
    if (info == null) throw Exception('Model not found: $cropName');

    final filePath = await getModelFilePath(cropName);

    try {
      await _dio.download(
        info.url,
        filePath,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: onProgress,
        options: Options(
          headers: {'Accept': '*/*'},
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 5),
        ),
      );
    } catch (e) {
      // If download fails, ensure partial file is deleted
      await deleteModel(cropName);
      rethrow;
    }
  }

  Future<void> deleteModel(String cropName) async {
    try {
      final filePath = await getModelFilePath(cropName);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete model: $e');
    }
  }

  Future<double> getTotalSize() async {
    double total = 0.0;
    for (final entry in modelInfo.entries) {
      final isDownloaded = await isModelDownloaded(entry.key);
      if (isDownloaded) {
        total += entry.value.size;
      }
    }
    return total;
  }

  // Get actual file size on disk (optional, for more accurate size tracking)
  Future<double> getActualFileSize(String cropName) async {
    try {
      final filePath = await getModelFilePath(cropName);
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.length();
        return bytes / (1024 * 1024); // Convert to MB
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }
}

class ModelInfo {
  final String url;
  final double size; // in MB
  final String fileName;

  ModelInfo({required this.url, required this.size, required this.fileName});
}
